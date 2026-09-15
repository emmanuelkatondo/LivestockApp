from rest_framework import viewsets, status, generics
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework_simplejwt.tokens import RefreshToken
from django.db import transaction
from django.utils import timezone
from django.db.models import Q, Count
from django.shortcuts import get_object_or_404
from .models import *
from .serializers import *
from .permissions import *

class RegisterView(generics.CreateAPIView):
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]
    
    @transaction.atomic
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
     
        if user.role == User.Role.FARMER:
            owner, created = Owner.objects.get_or_create(primary_owner=user)
            owner.users.add(user)
            print(f"Auto-created Owner profile for {user.first_name} (ID: {owner.id})")
        
        refresh = RefreshToken.for_user(user)
        
        return Response({
            'user': UserSerializer(user).data,
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        }, status=status.HTTP_201_CREATED)

class LoginView(generics.GenericAPIView):
    serializer_class = LoginSerializer
    permission_classes = [AllowAny]
    
    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']
        
        refresh = RefreshToken.for_user(user)
    
        user.last_login = timezone.now()
        user.save(update_fields=['last_login'])
        
        return Response({
            'user': UserSerializer(user).data,
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        })


class UserViewSet(viewsets.ModelViewSet):
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        if user.is_ag_officer or user.is_police:
            return User.objects.all()
        return User.objects.filter(id=user.id)

    @action(detail=False, methods=['get'], url_path='search_by_phone')
    def search_by_phone(self, request):
        """Search user by phone number - excludes current user"""
        phone = request.query_params.get('phone')
        
        if not phone:
            return Response(
                {"error": "Phone number is required"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            from .serializers import normalize_phone_number
            normalized_phone = normalize_phone_number(phone)
        except Exception as e:
            return Response(
                {"error": str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            user = User.objects.get(phone=normalized_phone)
            
            if user.id == request.user.id:
                return Response(
                    {"error": "You cannot transfer ownership to yourself"},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            if not user.is_farmer:
                return Response(
                    {"error": "User must be a farmer to receive ownership"},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            serializer = UserSerializer(user)
            return Response(serializer.data)
            
        except User.DoesNotExist:
            return Response(
                {"error": "User with this phone number does not exist"},
                status=status.HTTP_404_NOT_FOUND
            )
    
    @action(detail=False, methods=['get'], url_path='me')
    def me(self, request):
        """Get current user's profile"""
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def farmers(self, request):
        if not request.user.is_ag_officer:
            return Response({"error": "Not authorized"}, status=403)
        farmers = User.objects.filter(role=User.Role.FARMER)
        serializer = self.get_serializer(farmers, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def police(self, request):
        if not request.user.is_ag_officer:
            return Response({"error": "Not authorized"}, status=403)
        police = User.objects.filter(role=User.Role.POLICE)
        serializer = self.get_serializer(police, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['post'])
    def create_police(self, request):
        if not request.user.is_ag_officer:
            return Response({"error": "Not authorized"}, status=403)
        
        data = request.data.copy()
        data['role'] = User.Role.POLICE
        
        serializer = RegisterSerializer(data=data)
        if serializer.is_valid():
            user = serializer.save()
            return Response(UserSerializer(user).data, status=201)
        return Response(serializer.errors, status=400)
    
    @action(detail=True, methods=['patch'])
    def toggle_active(self, request, pk=None):
        if not request.user.is_ag_officer:
            return Response({"error": "Not authorized"}, status=403)
        
        user = self.get_object()
        user.is_active = not user.is_active
        user.save()
        
        return Response({
            "message": f"User {'activated' if user.is_active else 'deactivated'} successfully",
            "is_active": user.is_active
        })


class OwnerViewSet(viewsets.ModelViewSet):
    serializer_class = OwnerSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        if user.is_ag_officer or user.is_police:
            return Owner.objects.all()
        elif user.is_farmer:
            family_member_owners = Owner.objects.filter(users=user)
            if family_member_owners.exists():
                if family_member_owners.count() == 1:
                    return family_member_owners
                return family_member_owners
            return Owner.objects.filter(primary_owner=user)
        return Owner.objects.none()
    
    def get_serializer_class(self):
        if self.action == 'list_simple':
            return OwnerListSerializer
        return OwnerSerializer
    
    @action(detail=False, methods=['get'])
    def list_simple(self, request):
        owners = self.get_queryset()
        serializer = OwnerListSerializer(owners, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'], url_path='me')
    def me(self, request):
        """Get current user's owner profile (primary or family)"""
        user = request.user
        
        if not user.is_farmer:
            return Response(
                {"error": "User is not a farmer"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            family_owner = Owner.objects.filter(users=user).exclude(primary_owner=user).select_related('primary_owner').first()
            
            if family_owner:
                owner = family_owner
            else:
                owner = Owner.objects.filter(primary_owner=user).select_related('primary_owner').first()
            
            if not owner:
                return Response(
                    {"error": "Owner profile not found"},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            serializer = self.get_serializer(owner)
            return Response(serializer.data)
            
        except Exception as e:
            return Response(
                {"error": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    @action(detail=True, methods=['post'])
    def verify(self, request, pk=None):
        if not request.user.is_ag_officer:
            return Response({"error": "Not authorized"}, status=403)
        
        owner = self.get_object()
        owner.is_verified = True
        owner.verified_at = timezone.now()
        owner.save()
        
        Alert.objects.create(
            title="Account Verified",
            message=f"Your account has been verified by agricultural officer",
            alert_type=Alert.AlertType.GENERAL,
            user=owner.primary_owner if owner.primary_owner else owner.user
        )
        
        return Response({
            "message": "Owner verified successfully",
            "is_verified": owner.is_verified,
            "verified_at": owner.verified_at
        })
    
    @action(detail=True, methods=['get'])
    def animals(self, request, pk=None):
        """Get all animals for a specific owner"""
        owner = self.get_object()
        animals = Livestock.objects.filter(owner=owner)
        serializer = AnimalSerializer(animals, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['get'])
    def statistics(self, request, pk=None):
        owner = self.get_object()
        animals = Livestock.objects.filter(owner=owner)
        
        stats = {
            'total_animals': animals.count(),
            'active_animals': animals.filter(status=Livestock.AnimalStatus.ACTIVE).count(),
            'stolen_animals': animals.filter(status=Livestock.AnimalStatus.STOLEN).count(),
            'sold_animals': animals.filter(status=Livestock.AnimalStatus.SOLD).count(),
            'dead_animals': animals.filter(status=Livestock.AnimalStatus.DEAD).count(),
            'slaughtered_animals': animals.filter(status=Livestock.AnimalStatus.SLAUGHTERED).count(),
            'by_type': {
                'cattle': animals.filter(type=Livestock.AnimalType.CATTLE).count(),
                'goat': animals.filter(type=Livestock.AnimalType.GOAT).count(),
                'sheep': animals.filter(type=Livestock.AnimalType.SHEEP).count(),
                'other': animals.filter(type=Livestock.AnimalType.OTHER).count(),
            },
            'family_members': {
                'total': owner.users.count(),
                'primary': owner.primary_owner.full_name if owner.primary_owner else None,
                'members': [user.full_name for user in owner.users.all() if user != owner.primary_owner]
            }
        }
        
        return Response(stats)
    
    @action(detail=True, methods=['post'])
    def add_member(self, request, pk=None):
        """Add an existing user as a family member"""
        owner = self.get_object()
        
        if not request.user.is_ag_officer and request.user not in owner.users.all():
            return Response({"error": "Not authorized"}, status=403)
        
        phone = request.data.get('phone')
        if not phone:
            return Response({"error": "Phone number is required"}, status=400)
        
        try:
            from .serializers import normalize_phone_number
            normalized_phone = normalize_phone_number(phone)
            user = User.objects.get(phone=normalized_phone)
        except User.DoesNotExist:
            return Response({"error": "User with this phone number does not exist"}, status=404)
        except Exception as e:
            return Response({"error": str(e)}, status=400)
        
        if not user.is_farmer:
            return Response({"error": "User must be a farmer to be added as family member"}, status=400)
        
        if owner.users.filter(id=user.id).exists():
            return Response({"error": "User is already a family member"}, status=400)
        
        if owner.primary_owner == user:
            return Response({"error": "Primary owner cannot be added as family member"}, status=400)
        
        owner.users.add(user)
        
        Alert.objects.create(
            title="Added as Family Member",
            message=f"You have been added as a family member to {owner.primary_owner.full_name if owner.primary_owner else 'the farm'}'s farm",
            alert_type=Alert.AlertType.GENERAL,
            user=user
        )
        
        return Response({
            "message": f"User {user.full_name} added successfully",
            "user": UserSerializer(user).data
        }, status=201)
    
    @action(detail=True, methods=['post'])
    def register_family_member(self, request, pk=None):
        """Register a new family member and add them to this owner profile"""
        owner = self.get_object()
        

        if not request.user.is_ag_officer and request.user not in owner.users.all():
            return Response({"error": "Not authorized"}, status=403)
        
    
        phone = request.data.get('phone')
        first_name = request.data.get('first_name')
        last_name = request.data.get('last_name')
        password = request.data.get('password')
        confirm_password = request.data.get('confirm_password')
        email = request.data.get('email')
        location = request.data.get('location')
        
        if not phone:
            return Response({"error": "Phone number is required"}, status=400)
        if not first_name:
            return Response({"error": "First name is required"}, status=400)
        if not last_name:
            return Response({"error": "Last name is required"}, status=400)
        if not password:
            return Response({"error": "Password is required"}, status=400)
        if not confirm_password:
            return Response({"error": "Confirm password is required"}, status=400)
        
        if password != confirm_password:
            return Response({"error": "Passwords do not match"}, status=400)
     
        if len(password) < 8:
            return Response({"error": "Password must be at least 8 characters"}, status=400)
        if not any(c.isupper() for c in password):
            return Response({"error": "Password must contain at least one uppercase letter"}, status=400)
        if not any(c.islower() for c in password):
            return Response({"error": "Password must contain at least one lowercase letter"}, status=400)
        if not any(c.isdigit() for c in password):
            return Response({"error": "Password must contain at least one number"}, status=400)
        if not any(c in "!@#$%^&*(),.?\":{}|<>" for c in password):
            return Response({"error": "Password must contain at least one special character"}, status=400)
        
        try:
            from .serializers import normalize_phone_number
            normalized_phone = normalize_phone_number(phone)
            
            if User.objects.filter(phone=normalized_phone).exists():
                return Response({"error": "User with this phone number already exists"}, status=400)
   
            if email and User.objects.filter(email=email).exists():
                return Response({"error": "User with this email already exists"}, status=400)
 
            new_user = User.objects.create(
                phone=normalized_phone,
                first_name=first_name.strip(),
                last_name=last_name.strip(),
                email=email if email else None,
                location=location if location else None,
                role='FARMER',
                is_active=True
            )
            new_user.set_password(password)
            new_user.save()
            
            owner.users.add(new_user)
 
            Alert.objects.create(
                title="Added as Family Member",
                message=f"You have been added as a family member to {owner.primary_owner.full_name if owner.primary_owner else 'the farm'}'s farm",
                alert_type=Alert.AlertType.GENERAL,
                user=new_user
            )
            
            return Response({
                "message": f"User {new_user.full_name} registered and added as family member successfully",
                "user": UserSerializer(new_user).data
            }, status=201)
            
        except Exception as e:
            return Response({"error": str(e)}, status=400)
    
    @action(detail=True, methods=['post'])
    def remove_member(self, request, pk=None):
        """Remove a family member from this owner profile"""
        owner = self.get_object()
        
        if not request.user.is_ag_officer and request.user not in owner.users.all():
            return Response({"error": "Not authorized"}, status=403)
        
        user_id = request.data.get('user_id')
        if not user_id:
            return Response({"error": "user_id is required"}, status=400)
        
        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response({"error": "User not found"}, status=404)
        
        if owner.primary_owner == user:
            return Response({"error": "Cannot remove primary owner"}, status=400)
        
        if not owner.users.filter(id=user.id).exists():
            return Response({"error": "User is not a family member"}, status=400)
        
        owner.users.remove(user)
        
        return Response({
            "message": f"User {user.full_name} removed successfully"
        })
    
    @action(detail=True, methods=['get'])
    def members(self, request, pk=None):
        """Get all family members of this owner profile"""
        owner = self.get_object()
        
        if not request.user.is_ag_officer and request.user not in owner.users.all():
            return Response({"error": "Not authorized"}, status=403)
        
        users = owner.users.all()
        serializer = UserSerializer(users, many=True)
        
        return Response({
            "primary_owner": UserSerializer(owner.primary_owner).data if owner.primary_owner else None,
            "members": serializer.data,
            "total": users.count()
        })

class AnimalViewSet(viewsets.ModelViewSet):
    serializer_class = AnimalSerializer
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        if self.action == 'create':
            return AnimalCreateSerializer
        return AnimalSerializer
    
    def get_permissions(self):
        if self.action in ['create']:
            self.permission_classes = [IsAuthenticated, IsFarmer]
        elif self.action in ['update', 'partial_update', 'destroy']:
            self.permission_classes = [IsAuthenticated]
        else:
            self.permission_classes = [IsAuthenticated]
        return super().get_permissions()
    
    def get_queryset(self):
        user = self.request.user
        
        if user.is_ag_officer:
            return Livestock.objects.all().select_related('owner__primary_owner')
        elif user.is_police:
            return Livestock.objects.filter(
                status=Livestock.AnimalStatus.STOLEN
            ).select_related('owner__primary_owner')
        elif user.is_farmer:
            primary_owner = Owner.objects.filter(primary_owner=user).first()
            
            if primary_owner:
                return Livestock.objects.filter(
                    owner=primary_owner
                ).select_related('owner__primary_owner')
    
            family_owner = Owner.objects.filter(users=user).exclude(primary_owner=user).first()
            
            if family_owner:
      
                return Livestock.objects.filter(
                    owner=family_owner
                ).select_related('owner__primary_owner')
         
            
            return Livestock.objects.none()
        else:
            return Livestock.objects.none()
    
    def perform_create(self, serializer):
        user = self.request.user
     
        owner_profile = Owner.objects.filter(users=user).first()
        
        if not owner_profile:
     
            owner_profile = Owner.objects.create(primary_owner=user)
            owner_profile.users.add(user)
        
        serializer.save(owner=owner_profile)
    
    @action(detail=True, methods=['patch'])
    def update_status(self, request, pk=None):
        livestock = self.get_object()

        is_member = livestock.owner.users.filter(id=request.user.id).exists()
        if not is_member and not request.user.is_ag_officer:
            return Response(
                {"error": "Not authorized"}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        new_status = request.data.get('status')
        if not new_status:
            return Response(
                {"error": "Status is required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        valid_statuses = [choice[0] for choice in Livestock.AnimalStatus.choices]
        if new_status not in valid_statuses:
            return Response(
                {"error": f"Invalid status. Must be one of: {valid_statuses}"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        old_status = livestock.status
        livestock.status = new_status
        livestock.save()
        
        if new_status == Livestock.AnimalStatus.STOLEN and old_status != Livestock.AnimalStatus.STOLEN:

            for user in livestock.owner.users.all():
                Alert.objects.create(
                    title="Stolen Animal Alert",
                    message=f"Livestock {livestock.name} ({livestock.animal_id}) has been reported stolen",
                    alert_type=Alert.AlertType.THEFT,
                    animal=livestock,
                    user=user
                )
   
            police_users = User.objects.filter(role=User.Role.POLICE, is_active=True)
            for police in police_users:
                Alert.objects.create(
                    title="Stolen Animal Alert",
                    message=f"Livestock {livestock.name} ({livestock.animal_id}) owned by {livestock.owner.primary_owner.full_name if livestock.owner.primary_owner else 'Unknown'} has been reported stolen",
                    alert_type=Alert.AlertType.THEFT,
                    animal=livestock,
                    user=police
                )
     
        elif new_status == Livestock.AnimalStatus.ACTIVE and old_status == Livestock.AnimalStatus.STOLEN:
            for user in livestock.owner.users.all():
                Alert.objects.create(
                    title="Animal Recovered",
                    message=f"Livestock {livestock.name} ({livestock.animal_id}) has been recovered",
                    alert_type=Alert.AlertType.GENERAL,
                    animal=livestock,
                    user=user
                )
        
        return Response(self.get_serializer(livestock).data)
    
    @action(detail=True, methods=['get'])
    def locations(self, request, pk=None):
        livestock = self.get_object()
        days = request.query_params.get('days', 30)
        
        try:
            days = int(days)
        except ValueError:
            days = 30
        
  
        if days > 90:
            days = 90
        
        locations = livestock.locations.filter(
            timestamp__gte=timezone.now() - timezone.timedelta(days=days)
        ).order_by('-timestamp')[:500]
        
        serializer = LocationSerializer(locations, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['get'])
    def location_history(self, request, pk=None):
        livestock = self.get_object()
        
    
        is_member = livestock.owner.users.filter(id=request.user.id).exists()
        if not is_member and not request.user.is_ag_officer and not request.user.is_police:
            return Response(
                {"error": "Not authorized"}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        locations = livestock.locations.all().order_by('-timestamp')[:100]
        serializer = LocationSerializer(locations, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['get'])
    def statistics(self, request, pk=None):
        """Get detailed statistics for a specific animal"""
        livestock = self.get_object()

        is_member = livestock.owner.users.filter(id=request.user.id).exists()
        if not is_member and not request.user.is_ag_officer:
            return Response(
                {"error": "Not authorized"}, 
                status=status.HTTP_403_FORBIDDEN
            )
   
        total_locations = livestock.locations.count()
        last_location = livestock.locations.order_by('-timestamp').first()
    
        transfers = livestock.transfers.all()
        total_transfers = transfers.count()
        last_transfer = transfers.order_by('-initiated_at').first()
        
        stats = {
            'animal_id': livestock.animal_id,
            'name': livestock.name,
            'type': livestock.type,
            'status': livestock.status,
            'created_at': livestock.created_at,
            'updated_at': livestock.updated_at,
            'location_stats': {
                'total_locations': total_locations,
                'last_location': {
                    'latitude': last_location.latitude if last_location else None,
                    'longitude': last_location.longitude if last_location else None,
                    'timestamp': last_location.timestamp if last_location else None,
                } if last_location else None
            },
            'transfer_stats': {
                'total_transfers': total_transfers,
                'last_transfer': {
                    'status': last_transfer.status if last_transfer else None,
                    'initiated_at': last_transfer.initiated_at if last_transfer else None,
                    'to_user': last_transfer.to_user.first_name if last_transfer else None,
                } if last_transfer else None
            }
        }
        
        return Response(stats)
    
    @action(detail=True, methods=['post'])
    def link_gps(self, request, pk=None):
        """Link a GPS device to this animal"""
        livestock = self.get_object()

        is_member = livestock.owner.users.filter(id=request.user.id).exists()
        if not is_member and not request.user.is_ag_officer:
            return Response(
                {"error": "Not authorized"}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        device_id = request.data.get('device_id')
        if not device_id:
            return Response(
                {"error": "device_id is required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            device = GPSDevice.objects.get(device_id=device_id)
        except GPSDevice.DoesNotExist:
            return Response(
                {"error": "GPS device not found"}, 
                status=status.HTTP_404_NOT_FOUND
            )

        if device.animal and device.animal != livestock:
            return Response(
                {"error": f"Device already linked to {device.animal.name}"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        device.animal = livestock
        device.status = GPSDevice.GPSStatus.ACTIVE
        device.save()
 
        for user in livestock.owner.users.all():
            Alert.objects.create(
                title="GPS Device Linked",
                message=f"GPS device {device.device_id} has been linked to {livestock.name}",
                alert_type=Alert.AlertType.GENERAL,
                animal=livestock,
                user=user
            )
        
        return Response({
            "message": "GPS device linked successfully",
            "device": GPSDeviceSerializer(device).data
        })
    
    @action(detail=True, methods=['post'])
    def unlink_gps(self, request, pk=None):
        """Unlink GPS device from this animal"""
        livestock = self.get_object()
        
        # Check ownership
        is_member = livestock.owner.users.filter(id=request.user.id).exists()
        if not is_member and not request.user.is_ag_officer:
            return Response(
                {"error": "Not authorized"}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        if not livestock.gps_devices.exists():
            return Response(
                {"error": "No GPS device linked to this animal"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
 
        devices = livestock.gps_devices.all()
        count = devices.update(animal=None, status=GPSDevice.GPSStatus.INACTIVE)
    
        for user in livestock.owner.users.all():
            Alert.objects.create(
                title="GPS Device Unlinked",
                message=f"GPS device has been unlinked from {livestock.name}",
                alert_type=Alert.AlertType.GENERAL,
                animal=livestock,
                user=user
            )
        
        return Response({
            "message": f"Unlinked {count} GPS device(s) successfully"
        })
    
    @action(detail=False, methods=['get'])
    def by_status(self, request):
        """Get animals filtered by status"""
        status_filter = request.query_params.get('status')
        
        if not status_filter:
            return Response(
                {"error": "status parameter is required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Validate status
        valid_statuses = [choice[0] for choice in Livestock.AnimalStatus.choices]
        if status_filter not in valid_statuses:
            return Response(
                {"error": f"Invalid status. Must be one of: {valid_statuses}"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        queryset = self.get_queryset().filter(status=status_filter)
        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def by_type(self, request):
        """Get animals filtered by type"""
        type_filter = request.query_params.get('type')
        
        if not type_filter:
            return Response(
                {"error": "type parameter is required"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
      
        valid_types = [choice[0] for choice in Livestock.AnimalType.choices]
        if type_filter not in valid_types:
            return Response(
                {"error": f"Invalid type. Must be one of: {valid_types}"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        queryset = self.get_queryset().filter(type=type_filter)
        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['delete'])
    def soft_delete(self, request, pk=None):
        """Soft delete an animal (mark as inactive)"""
        livestock = self.get_object()
  
        is_member = livestock.owner.users.filter(id=request.user.id).exists()
        if not is_member and not request.user.is_ag_officer:
            return Response(
                {"error": "Not authorized"}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        livestock.is_active = False
        livestock.save()
        

        for user in livestock.owner.users.all():
            Alert.objects.create(
                title="Animal Deactivated",
                message=f"Livestock {livestock.name} ({livestock.animal_id}) has been deactivated",
                alert_type=Alert.AlertType.GENERAL,
                animal=livestock,
                user=user
            )
        
        return Response({
            "message": f"Animal {livestock.name} has been deactivated successfully"
        })

class GPSDeviceViewSet(viewsets.ModelViewSet):
    serializer_class = GPSDeviceSerializer
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        if self.action == 'create':
            return GPSDeviceCreateSerializer
        return GPSDeviceSerializer
    
    def get_queryset(self):
        user = self.request.user
        if user.is_ag_officer:
            return GPSDevice.objects.all()
        elif user.is_farmer:
     
            family_owner = Owner.objects.filter(users=user).exclude(primary_owner=user).first()
            
            if family_owner:
  
                return GPSDevice.objects.filter(
                    Q(animal__owner=family_owner) | Q(animal__isnull=True)
                )
    
            owner_profile = Owner.objects.filter(primary_owner=user).first()
            if owner_profile:
                return GPSDevice.objects.filter(
                    Q(animal__owner=owner_profile) | Q(animal__isnull=True)
                )
            
            return GPSDevice.objects.none()
        elif user.is_police:
            return GPSDevice.objects.filter(animal__status=Livestock.AnimalStatus.STOLEN)
        return GPSDevice.objects.none()
    
    @action(detail=True, methods=['post'])
    def link_animal(self, request, pk=None):
        device = self.get_object()
        animal_id = request.data.get('animal_id')
        
        if not animal_id:
            return Response({"error": "animal_id required"}, status=400)
        
        try:
            animal = Livestock.objects.get(id=animal_id)
      
            is_member = animal.owner.users.filter(id=request.user.id).exists()
            if not is_member and not request.user.is_ag_officer:
                return Response({"error": "You don't own this animal"}, status=403)
            
            if device.animal and device.animal != animal:
                return Response(
                    {"error": f"Device already linked to {device.animal.name}"}, 
                    status=400
                )
            
            device.animal = animal
            device.status = GPSDevice.GPSStatus.ACTIVE
            device.save()
            
            return Response(self.get_serializer(device).data)
            
        except Livestock.DoesNotExist:
            return Response({"error": "Animal not found"}, status=404)
    
    @action(detail=True, methods=['post'])
    def unlink_animal(self, request, pk=None):
        device = self.get_object()
        
        if device.animal:
            is_member = device.animal.owner.users.filter(id=request.user.id).exists()
            if not is_member and not request.user.is_ag_officer:
                return Response({"error": "Not authorized"}, status=403)
        
        device.animal = None
        device.status = GPSDevice.GPSStatus.INACTIVE
        device.save()
        
        return Response({"message": "Device unlinked successfully"})
    
    @action(detail=True, methods=['post'])
    def update_battery(self, request, pk=None):
        device = self.get_object()
        battery_level = request.data.get('battery_level')
        
        if battery_level is not None:
            try:
                battery_level = int(battery_level)
                if 0 <= battery_level <= 100:
                    device.battery_level = battery_level
                    device.last_online = timezone.now()
                    device.save()
                else:
                    return Response({"error": "Battery level must be between 0 and 100"}, status=400)
            except ValueError:
                return Response({"error": "Battery level must be a number"}, status=400)
        
        return Response(self.get_serializer(device).data)



class LocationViewSet(viewsets.ModelViewSet):
    serializer_class = LocationSerializer

    def get_permissions(self):
        if self.action == "create":
            return [AllowAny()]
        return [IsAuthenticated()]

    def get_serializer_class(self):
        if self.action == 'create':
            return LocationCreateSerializer
        return LocationSerializer
    
    def get_queryset(self):
        user = self.request.user
        
        if user.is_ag_officer:
            return Location.objects.all()
        elif user.is_farmer:
       
            family_owner = Owner.objects.filter(users=user).exclude(primary_owner=user).first()
            
            if family_owner:
                return Location.objects.filter(animal__owner=family_owner)
            
     
            owner_profile = Owner.objects.filter(primary_owner=user).first()
            if owner_profile:
                return Location.objects.filter(animal__owner=owner_profile)
            
            return Location.objects.none()
        elif user.is_police:
            return Location.objects.filter(animal__status=Livestock.AnimalStatus.STOLEN)
        return Location.objects.none()
    
    def perform_create(self, serializer):
        location = serializer.save()
        
        # Create alert for location update for all family members
        animal = location.animal
        if animal and animal.status == Livestock.AnimalStatus.ACTIVE:
            for user in animal.owner.users.all():
                Alert.objects.create(
                    title="Animal Location Update",
                    message=f"{animal.name} is at new location: {location.latitude}, {location.longitude}",
                    alert_type=Alert.AlertType.LOST,
                    animal=animal,
                    user=user
                )


class OwnershipTransferViewSet(viewsets.ModelViewSet):
    serializer_class = OwnershipTransferSerializer
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        if self.action == 'create':
            return OwnershipTransferCreateSerializer
        return OwnershipTransferSerializer
    
    def get_queryset(self):
        user = self.request.user
        if user.is_ag_officer:
            return OwnershipTransfer.objects.all()
        return OwnershipTransfer.objects.filter(Q(from_user=user) | Q(to_user=user))
    
    def create(self, request, *args, **kwargs):
        data = request.data.copy()
        
        serializer = self.get_serializer(data=data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)
    
    def perform_create(self, serializer):
        transfer = serializer.save(from_user=self.request.user)
        
        Alert.objects.create(
            title="Ownership Transfer Request",
            message=f"{self.request.user.full_name} wants to transfer {transfer.animal.name} to you",
            alert_type=Alert.AlertType.GENERAL,
            user=transfer.to_user
        )
    


    @action(detail=True, methods=['post'])
    def confirm(self, request, pk=None):
        transfer = self.get_object()
        
        if transfer.to_user != request.user:
            return Response({"error": "You are not the recipient"}, status=status.HTTP_403_FORBIDDEN)
        
        if transfer.status != OwnershipTransfer.TransferStatus.PENDING:
            return Response(
                {"error": f"Transfer is already {transfer.status}"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if transfer.expiry_date and timezone.now() > transfer.expiry_date:
            transfer.status = OwnershipTransfer.TransferStatus.EXPIRED
            transfer.save()
            return Response({"error": "Transfer has expired"}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            recipient_owner = Owner.objects.filter(primary_owner=transfer.to_user).first()
            
            if not recipient_owner:
                recipient_owner = Owner.objects.filter(users=transfer.to_user).first()
                
                if not recipient_owner:
                    recipient_owner = Owner.objects.create(primary_owner=transfer.to_user)
                    recipient_owner.users.add(transfer.to_user)
                    print(f"Created new owner profile: {recipient_owner.id}")
                else:
                    recipient_owner.primary_owner = transfer.to_user
                    recipient_owner.save()
                    print(f" Set primary owner for existing profile: {recipient_owner.id}")
            else:
                print(f"Found owner profile: {recipient_owner.id}")
            
            if transfer.to_user not in recipient_owner.users.all():
                recipient_owner.users.add(transfer.to_user)
                print(f"Added {transfer.to_user.first_name} to users")
                
        except Exception as e:
            print(f"Error getting/creating owner profile: {e}")
            return Response(
                {"error": f"Failed to get/create owner profile: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        transfer.status = OwnershipTransfer.TransferStatus.CONFIRMED
        transfer.confirmed_at = timezone.now()
        transfer.save()
   
        animal = transfer.animal
    
        old_owner = animal.owner
        old_owner_name = old_owner.user.first_name if old_owner and old_owner.user else "Unknown"
        animal.owner = recipient_owner
        animal.save()
        
        print(f"Animal {animal.name} transferred from {old_owner_name} to {recipient_owner.user.first_name}")
        for user in recipient_owner.users.all():
            Alert.objects.create(
                title="Transfer Successful",
                message=f"You have successfully received {animal.name}",
                alert_type=Alert.AlertType.GENERAL,
                user=user
            )
        
        return Response(self.get_serializer(transfer).data)
    
    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        transfer = self.get_object()
        
        if transfer.to_user != request.user:
            return Response({"error": "Not authorized"}, status=status.HTTP_403_FORBIDDEN)
        
        if transfer.status != OwnershipTransfer.TransferStatus.PENDING:
            return Response(
                {"error": f"Transfer is already {transfer.status}"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        transfer.status = OwnershipTransfer.TransferStatus.REJECTED
        transfer.save()
        
        Alert.objects.create(
            title="Transfer Rejected",
            message=f"{request.user.full_name} has rejected the transfer of {transfer.animal.name}",
            alert_type=Alert.AlertType.GENERAL,
            user=transfer.from_user
        )
        
        return Response(self.get_serializer(transfer).data)

class AlertViewSet(viewsets.ModelViewSet):
    serializer_class = AlertSerializer
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        if self.action == 'create':
            return AlertCreateSerializer
        return AlertSerializer
    
    def get_queryset(self):
        user = self.request.user
        
        if user.is_ag_officer:
            return Alert.objects.all()
        elif user.is_police:
            return Alert.objects.filter(alert_type=Alert.AlertType.THEFT)
        elif user.is_farmer:
    
            owner_profiles = Owner.objects.filter(users=user)
            return Alert.objects.filter(
                Q(animal__owner__in=owner_profiles) | Q(user=user)
            ).distinct()
        else:
            return Alert.objects.none()
    
    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        alert = self.get_object()
        alert.is_read = True
        alert.save()
        return Response({"status": "marked as read", "is_read": True})
    
    @action(detail=False, methods=['post'])
    def mark_all_read(self, request):
        alerts = self.get_queryset().filter(is_read=False)
        count = alerts.update(is_read=True)
        return Response({"message": f"Marked {count} alerts as read"})

class BroadcastMessageViewSet(viewsets.ModelViewSet):
    serializer_class = BroadcastMessageSerializer
    permission_classes = [IsAuthenticated, IsAgOfficer]
    
    def get_serializer_class(self):
        if self.action == 'create':
            return BroadcastMessageCreateSerializer
        return BroadcastMessageSerializer
    
    def get_queryset(self):
        return BroadcastMessage.objects.all().order_by('-sent_at')
    
    def perform_create(self, serializer):
        message = serializer.save(sender=self.request.user)
        
        farmers = User.objects.filter(role=User.Role.FARMER, is_active=True)
        message.recipients.set(farmers)
        
        for farmer in farmers:
            Alert.objects.create(
                title=message.title,
                message=message.message,
                alert_type=Alert.AlertType.GENERAL,
                user=farmer
            )


class LivestockReportViewSet(viewsets.ModelViewSet):
    serializer_class = LivestockReportSerializer
    permission_classes = [IsAuthenticated, IsAgOfficer]
    
    def get_serializer_class(self):
        if self.action == 'generate_population':
            return LivestockReportCreateSerializer
        return LivestockReportSerializer
    
    def get_queryset(self):
        return LivestockReport.objects.filter(generated_by=self.request.user).order_by('-generated_at')
    
    @action(detail=False, methods=['post'])
    def generate_population(self, request):
        start_date = request.data.get('start_date')
        end_date = request.data.get('end_date')
        
        if start_date:
            try:
                start_date = timezone.datetime.fromisoformat(start_date.replace('Z', '+00:00'))
            except ValueError:
                return Response({"error": "Invalid start_date format"}, status=400)
        else:
            start_date = timezone.now() - timezone.timedelta(days=30)
        
        if end_date:
            try:
                end_date = timezone.datetime.fromisoformat(end_date.replace('Z', '+00:00'))
            except ValueError:
                return Response({"error": "Invalid end_date format"}, status=400)
        else:
            end_date = timezone.now()
        
        animals = Livestock.objects.filter(created_at__range=[start_date, end_date])
        
        type_counts = {}
        for animal_type in Livestock.AnimalType.values:
            count = animals.filter(type=animal_type).count()
            if count > 0:
                type_counts[animal_type] = count
        
        status_counts = {}
        for status in Livestock.AnimalStatus.values:
            count = animals.filter(status=status).count()
            if count > 0:
                status_counts[status] = count
        
        report = LivestockReport.objects.create(
            generated_by=request.user,
            report_type=LivestockReport.ReportType.POPULATION,
            start_date=start_date,
            end_date=end_date,
            total_animals=animals.count(),
            animals_by_type=type_counts,
            animals_by_status=status_counts,
            stolen_reported=animals.filter(status=Livestock.AnimalStatus.STOLEN).count()
        )
        serializer = self.get_serializer(report)
        return Response(serializer.data)
        
       
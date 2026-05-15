from rest_framework import viewsets, status, generics
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework_simplejwt.tokens import RefreshToken
from django.utils import timezone
from django.db.models import Q
from .models import *
from .serializers import *
from .permissions import *

class RegisterView(generics.CreateAPIView):
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]
    
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        
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
        if user.is_ag_officer:
            return User.objects.all()
        return User.objects.filter(id=user.id)
    
    @action(detail=False, methods=['get'])
    def me(self, request):
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
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save(role=User.Role.POLICE)
            return Response(UserSerializer(user).data, status=201)
        return Response(serializer.errors, status=400)

# OWNER VIEWSET 
class OwnerViewSet(viewsets.ModelViewSet):
    serializer_class = OwnerSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        if user.is_ag_officer:
            return Owner.objects.all()
        elif user.is_farmer:
            return Owner.objects.filter(user=user)
        return Owner.objects.none()
    
    @action(detail=False, methods=['get'])
    def list_simple(self, request):
        owners = self.get_queryset()
        serializer = OwnerListSerializer(owners, many=True)
        return Response(serializer.data)
    
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
            message="Your account has been verified by agricultural officer",
            alert_type=Alert.AlertType.GENERAL,
            user=owner.user
        )
        
        
        return Response({"message": "Owner verified successfully"})
    
    @action(detail=True, methods=['get'])
    def animals(self, request, pk=None):
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
            }
        }
        
        return Response(stats)

class AnimalViewSet(viewsets.ModelViewSet):
    serializer_class = AnimalSerializer
    permission_classes = [IsAuthenticated]
    
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
            return Livestock.objects.all()
        elif user.is_police:
            return Livestock.objects.filter(status=Livestock.AnimalStatus.STOLEN)
        elif user.is_farmer:
            try:
                owner_profile = Owner.objects.get(user=user)
                return Livestock.objects.filter(owner=owner_profile)
            except Owner.DoesNotExist:
                return Livestock.objects.none()
        else:
            return Livestock.objects.none()
    
    def perform_create(self, serializer):
        user = self.request.user
        owner_profile, created = Owner.objects.get_or_create(user=user)
        livestock = serializer.save(owner=owner_profile)
    
    def perform_update(self, serializer):
        livestock = serializer.save()
        
    def perform_destroy(self, instance):
        instance.delete()
    
    @action(detail=True, methods=['patch'])
    def update_status(self, request, pk=None):
        livestock = self.get_object()
        
        is_owner = livestock.owner.user == request.user
        if not is_owner and not request.user.is_ag_officer:
            return Response({"error": "Not authorized"}, status=status.HTTP_403_FORBIDDEN)
        
        new_status = request.data.get('status')
        if not new_status:
            return Response({"error": "Status is required"}, status=status.HTTP_400_BAD_REQUEST)
        
        livestock.status = new_status
        livestock.save()
        
        if new_status == Livestock.AnimalStatus.STOLEN:
            Alert.objects.create(
                title="Stolen Animal Alert",
                message=f"Livestock {livestock.name} ({livestock.animal_id}) has been reported stolen",
                alert_type=Alert.AlertType.THEFT,
                animal=livestock,
                user=livestock.owner.user
            )
        
        return Response(self.get_serializer(livestock).data)
    
    @action(detail=True, methods=['get'])
    def locations(self, request, pk=None):
        livestock = self.get_object()
        days = request.query_params.get('days', 30)
        locations = livestock.locations.filter(
            timestamp__gte=timezone.now() - timezone.timedelta(days=int(days))
        )[:500]
        serializer = LocationSerializer(locations, many=True)
        return Response(serializer.data)

class GPSDeviceViewSet(viewsets.ModelViewSet):
    serializer_class = GPSDeviceSerializer
    
    def get_permissions(self):
        if self.action in ['create', 'update', 'destroy', 'link_animal']:
            self.permission_classes = [IsAuthenticated]
        else:
            self.permission_classes = [AllowAny]
        return super().get_permissions()
    
    def get_queryset(self):
        user = self.request.user
        if user.is_ag_officer:
            return GPSDevice.objects.all()
        elif user.is_farmer:
            return GPSDevice.objects.filter(
                Q(animal__owner__user=user) | Q(animal__isnull=True)
            )
        return GPSDevice.objects.none()
    
    def perform_create(self, serializer):
        device = serializer.save()
        
    @action(detail=True, methods=['post'])
    def link_animal(self, request, pk=None):
        device = self.get_object()
        animal_id = request.data.get('animal_id')
        
        if not animal_id:
            return Response({"error": "animal_id required"}, status=400)
        
        try:
            animal = Livestock.objects.get(id=animal_id)

            if animal.owner.user != request.user and not request.user.is_ag_officer:
                return Response({"error": "You don't own this animal"}, status=403)

            if device.animal and device.animal != animal:
                return Response(
                    {"error": f"Device already linked to {device.animal.name}"}, 
                    status=400
                )
            
            device.animal = animal
            device.save()
            
            return Response(self.get_serializer(device).data)
            
        except Livestock.DoesNotExist:
            return Response({"error": "Animal not found"}, status=404)
    
    @action(detail=True, methods=['post'])
    def update_battery(self, request, pk=None):
        device = self.get_object()
        battery_level = request.data.get('battery_level')
        
        if battery_level is not None:
            device.battery_level = battery_level
            device.last_online = timezone.now()
            device.save()
        
        return Response(self.get_serializer(device).data)
        
class LocationViewSet(viewsets.ModelViewSet):
    serializer_class = LocationSerializer
    permission_classes = [AllowAny]
    
    def get_queryset(self):
        user = self.request.user
        if user.is_ag_officer:
            return Location.objects.all()
        elif user.is_farmer:
            return Location.objects.filter(animal__owner__user=user)
        return Location.objects.none()
    
    def perform_create(self, serializer):
        location = serializer.save()

        animal = location.animal
        if animal.status == Livestock.AnimalStatus.ACTIVE:
            Alert.objects.create(
                title="Animal Location Update",
                message=f"{animal.name} is at new location",
                alert_type=Alert.AlertType.LOST,
                animal=animal,
                user=animal.owner.user
            )

class OwnershipTransferViewSet(viewsets.ModelViewSet):
    serializer_class = OwnershipTransferSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        if user.is_ag_officer:
            return OwnershipTransfer.objects.all()
        return OwnershipTransfer.objects.filter(Q(from_user=user) | Q(to_user=user))
    
    def create(self, request, *args, **kwargs):
        
        serializer = self.get_serializer(data=request.data)
        
        if not serializer.is_valid():
            print("Serializer errors:", serializer.errors)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        to_user_id = request.data.get('to_user')
        try:
            to_user = User.objects.get(id=to_user_id)
            if not to_user.is_farmer:
                return Response(
                    {"error": "Transfer can only be made to a farmer"},
                    status=status.HTTP_400_BAD_REQUEST
                )
        except User.DoesNotExist:
            return Response(
                {"error": "Recipient user not found"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)
    
    def perform_create(self, serializer):
        transfer = serializer.save(from_user=self.request.user)
        
        Alert.objects.create(
            title="Ownership Transfer Request",
            message=f"{self.request.user.first_name} wants to transfer {transfer.animal.name} to you",
            alert_type=Alert.AlertType.GENERAL,
            user=transfer.to_user
        )
    
    @action(detail=True, methods=['post'])
    def confirm(self, request, pk=None):
        transfer = self.get_object()

        if transfer.to_user != request.user:
            return Response({"error": "You are not the recipient"}, status=status.HTTP_403_FORBIDDEN)

        if timezone.now() > transfer.expiry_date:
            transfer.status = OwnershipTransfer.TransferStatus.EXPIRED
            transfer.save()
            return Response({"error": "Transfer expired"}, status=status.HTTP_400_BAD_REQUEST)
        
        if transfer.status != OwnershipTransfer.TransferStatus.PENDING:
            return Response({"error": f"Transfer is already {transfer.status}"}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            recipient_owner = Owner.objects.get(user=transfer.to_user)
        except Owner.DoesNotExist:
            recipient_owner = Owner.objects.create(user=transfer.to_user)

        transfer.status = OwnershipTransfer.TransferStatus.CONFIRMED
        transfer.confirmed_at = timezone.now()
        transfer.save()

        animal = transfer.animal
        animal.owner = recipient_owner 
        animal.save()

        Alert.objects.create(
            title="Transfer Confirmed",
            message=f"{request.user.first_name} has accepted the transfer of {animal.name}",
            alert_type=Alert.AlertType.GENERAL,
            user=transfer.from_user
        )
        
        return Response(self.get_serializer(transfer).data)
    
    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        transfer = self.get_object()
    
        if transfer.to_user != request.user:
            return Response({"error": "Not authorized"}, status=status.HTTP_403_FORBIDDEN)

        if transfer.status != OwnershipTransfer.TransferStatus.PENDING:
            return Response({"error": f"Transfer is already {transfer.status}"}, status=status.HTTP_400_BAD_REQUEST)
        
        transfer.status = OwnershipTransfer.TransferStatus.REJECTED
        transfer.save()

        Alert.objects.create(
            title="Transfer Rejected",
            message=f"{request.user.first_name} has rejected the transfer of {transfer.animal.name}",
            alert_type=Alert.AlertType.GENERAL,
            user=transfer.from_user
        )
        
        return Response(self.get_serializer(transfer).data)

class AlertViewSet(viewsets.ModelViewSet):
    serializer_class = AlertSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        
        if user.is_ag_officer:
            return Alert.objects.all()
        elif user.is_police:
            return Alert.objects.filter(alert_type=Alert.AlertType.THEFT)
        elif user.is_farmer:
            try:
                owner_profile = Owner.objects.get(user=user)
                return Alert.objects.filter(
                    Q(animal__owner=owner_profile) | Q(user=user)
                )
            except Owner.DoesNotExist:
                return Alert.objects.filter(user=user)
        else:
            return Alert.objects.none()
    
    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        alert = self.get_object()
        alert.is_read = True
        alert.save()
        return Response({"status": "marked as read"})

class BroadcastMessageViewSet(viewsets.ModelViewSet):
    serializer_class = BroadcastMessageSerializer
    permission_classes = [IsAuthenticated, IsAgOfficer]
    
    def get_queryset(self):
        return BroadcastMessage.objects.all()
    
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
    
    def get_queryset(self):
        return LivestockReport.objects.filter(generated_by=self.request.user)
    
    @action(detail=False, methods=['post'])
    def generate_population(self, request):
        animals = Livestock.objects.all()
        
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
            start_date=timezone.now() - timezone.timedelta(days=30),
            end_date=timezone.now(),
            total_animals=animals.count(),
            animals_by_type=type_counts,
            animals_by_status=status_counts,
            stolen_reported=animals.filter(status=Livestock.AnimalStatus.STOLEN).count()
        )
        
        return Response(self.get_serializer(report).data)

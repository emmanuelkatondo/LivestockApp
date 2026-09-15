from rest_framework import serializers
from django.contrib.auth import authenticate
from django.contrib.auth import get_user_model
from django.db.models import Count, Q
from datetime import datetime
from .models import *

User = get_user_model()
def normalize_phone_number(value):
   
    phone = str(value).strip().replace(" ", "").replace("-", "").replace("+", "")
    
    if phone.startswith('0'):
        if len(phone) != 10:
            raise serializers.ValidationError(
                "Phone number starting with 0 must have exactly 10 digits (e.g., 0712345678)"
            )
        if not phone.isdigit():
            raise serializers.ValidationError("Phone number must contain only digits")
        phone = '255' + phone[1:]
    elif phone.startswith('255'):
        if len(phone) != 12:
            raise serializers.ValidationError(
                "Phone number starting with 255 must have exactly 12 digits (e.g., 255712345678)"
            )
        if not phone.isdigit():
            raise serializers.ValidationError("Phone number must contain only digits")

    elif phone.startswith(('7', '6')):
        if len(phone) != 9:
            raise serializers.ValidationError(
                "Phone number starting with 6 or 7 must have exactly 9 digits (e.g., 712345678)"
            )
        if not phone.isdigit():
            raise serializers.ValidationError("Phone number must contain only digits")
        phone = '255' + phone
    else:
        raise serializers.ValidationError(
            "Phone number must be in Tanzania format: 0712345678"
        )
    
    number_part = phone[3:]  
    
    valid_prefixes = [
        '71', '74', '75', '76',  # Vodacom
        '78', '79',              # Airtel
        '65', '66', '67', '68', '69', '70',  # Tigo (yas)
        '61', '62',              # Halotel
    ]
    
    prefix = number_part[:2]
    if prefix not in valid_prefixes:
        raise serializers.ValidationError(
            f"Invalid network prefix '{prefix}'. Use Vodacom, Airtel, Tigo (yas), or Halotel"
        )
    
    return phone

def validate_name(value, field_name):
    """Validate name fields (3-10 characters, letters only)"""
    if not value or not value.strip():
        raise serializers.ValidationError(f"{field_name} is required")
    
    name = value.strip()
    
    if len(name) < 3:
        raise serializers.ValidationError(f"{field_name} must be at least 3 characters")
    
    if len(name) > 10:
        raise serializers.ValidationError(f"{field_name} must be less than 10 characters")
    
    if not name.replace(" ", "").isalpha():
        raise serializers.ValidationError(f"{field_name} can only contain letters")
    
    return name

def validate_password(value):
    """Validate password strength"""
    if len(value) < 8:
        raise serializers.ValidationError("Password must be at least 8 characters")
    
    if not any(char.isupper() for char in value):
        raise serializers.ValidationError("Password must contain at least one uppercase letter")
    
    if not any(char.islower() for char in value):
        raise serializers.ValidationError("Password must contain at least one lowercase letter")
    
    if not any(char.isdigit() for char in value):
        raise serializers.ValidationError("Password must contain at least one number")
    
    if not any(char in "!@#$%^&*(),.?\":{}|<>" for char in value):
        raise serializers.ValidationError(
            "Password must contain at least one special character (!@#$%^&*(),.?\":{}|<>)"
        )
    
    return value

def get_full_name(user):
    """Get full name from user model"""
    if not user:
        return ''
    parts = [user.first_name]
    if user.middle_name:
        parts.append(user.middle_name)
    if user.last_name:
        parts.append(user.last_name)
    return ' '.join(parts)

class UserSerializer(serializers.ModelSerializer):
    full_name = serializers.SerializerMethodField()
    animal_count = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = [
            'id', 'phone', 'first_name', 'middle_name', 'last_name', 'full_name',
            'email', 'role', 'location', 'profile_picture', 
            'is_active', 'is_staff', 'is_superuser',
            'date_joined', 'last_login',
            'animal_count',  
        ]
        read_only_fields = ['id', 'date_joined', 'last_login']
    
    def get_full_name(self, obj):
        return get_full_name(obj)
    
    def get_animal_count(self, obj):
        """Get total animals for this farmer"""
        try:
            owner = Owner.objects.filter(users=obj).first()
            if not owner:
                try:
                    owner = Owner.objects.get(user=obj)
                except Owner.DoesNotExist:
                    return 0
            
            return owner.animals.count() if owner else 0
        except Exception as e:
            print(f"Error getting animal count: {e}")
            return 0

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    confirm_password = serializers.CharField(write_only=True)
    middle_name = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    email = serializers.EmailField(required=False, allow_blank=True, allow_null=True)
    location = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    role = serializers.CharField(required=False, default='FARMER') 
    
    class Meta:
        model = User
        fields = [
            'phone', 'first_name', 'middle_name', 'last_name',
            'email', 'password', 'confirm_password', 'location', 'role'  
        ]
    
    def validate_first_name(self, value):
        return validate_name(value, "First name")
    
    def validate_middle_name(self, value):
        if value and value.strip():
            return validate_name(value, "Middle name")
        return value
    
    def validate_last_name(self, value):
        return validate_name(value, "Last name")
    
    def validate_phone(self, value):
        if not value:
            raise serializers.ValidationError("Phone number is required")
        return normalize_phone_number(value)
    
    def validate_password(self, value):
        return validate_password(value)
    
    def validate(self, data):
        if data['password'] != data['confirm_password']:
            raise serializers.ValidationError({
                "confirm_password": "Passwords do not match"
            })
        if 'phone' in data:
            normalized_phone = normalize_phone_number(data['phone'])
            if User.objects.filter(phone=normalized_phone).exists():
                raise serializers.ValidationError({
                    "phone": "User with this phone number already exists"
                })
            data['phone'] = normalized_phone
        
        email = data.get('email')
        if email and User.objects.filter(email=email).exists():
            raise serializers.ValidationError({
                "email": "User with this email already exists"
            })
        
        return data
    
    def create(self, validated_data):
        validated_data.pop('confirm_password')
        password = validated_data.pop('password')
        role = validated_data.pop('role', 'FARMER')  
       
        if 'middle_name' in validated_data:
            if validated_data['middle_name'] == '':
                validated_data['middle_name'] = None
        
        if 'email' in validated_data:
            if validated_data['email'] == '':
                validated_data['email'] = None
        
        if 'location' in validated_data:
            if validated_data['location'] == '':
                validated_data['location'] = None
        
        user = User(**validated_data)
        user.set_password(password)
        user.role = role 
        user.save()
        
        return user

class LoginSerializer(serializers.Serializer):
    phone = serializers.CharField()
    password = serializers.CharField(write_only=True)
    
    def validate(self, data):
        try:
            phone = normalize_phone_number(data['phone'])
        except serializers.ValidationError:
            phone = data['phone'].strip()
        try:
            user = User.objects.get(phone=phone)
        except User.DoesNotExist:
            raise serializers.ValidationError("Invalid phone number or password")
        
        if not user.check_password(data['password']):
            raise serializers.ValidationError("Invalid phone number or password")

        if not user.is_active:
            raise serializers.ValidationError("Account is disabled")
        
        return {'user': user}

class OwnerSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    user_name = serializers.SerializerMethodField()
    user_phone = serializers.CharField(source='user.phone', read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)
    user_location = serializers.CharField(source='user.location', read_only=True)
  
    primary_owner_info = UserSerializer(source='primary_owner', read_only=True)

    users_info = UserSerializer(source='users', many=True, read_only=True)
    
    class Meta:
        model = Owner
        fields = [
            'id', 
            'user', 'user_name', 'user_phone', 'user_email', 'user_location',
            'farm_name', 'farm_location', 'national_id', 'registration_number',
            'alternative_phone', 'emergency_contact', 
            'total_animals', 'total_gps_devices',
            'is_verified', 'verified_at', 'notes',
            'created_at', 'updated_at',
            'primary_owner',        
            'primary_owner_info',   
            'users',               
            'users_info',           
        ]
        read_only_fields = [
            'id', 'registration_number', 'total_animals', 
            'total_gps_devices', 'created_at', 'updated_at'
        ]
    
    def get_user_name(self, obj):
        return get_full_name(obj.user)

class OwnerListSerializer(serializers.ModelSerializer):
    user_name = serializers.SerializerMethodField()
    user_phone = serializers.CharField(source='user.phone', read_only=True)
    
    class Meta:
        model = Owner
        fields = ['id', 'user', 'user_name', 'user_phone']
    def get_user_name(self, obj):
        if obj.user:
            return get_full_name(obj.user)
        return ''

class OwnerCreateSerializer(serializers.ModelSerializer):
    phone = serializers.CharField(write_only=True)
    first_name = serializers.CharField(write_only=True)
    middle_name = serializers.CharField(write_only=True, required=False, allow_blank=True, allow_null=True)
    last_name = serializers.CharField(write_only=True)
    email = serializers.EmailField(write_only=True, required=False, allow_blank=True, allow_null=True)
    password = serializers.CharField(write_only=True, required=False)
    
    class Meta:
        model = Owner
        fields = [
            'phone', 'first_name', 'middle_name', 'last_name', 'email',
            'password', 'farm_name', 'farm_location', 'national_id',
            'alternative_phone', 'emergency_contact', 'notes'
        ]
    
    def validate_phone(self, value):
        if not value:
            raise serializers.ValidationError("Phone number is required")
        return normalize_phone_number(value)
    
    def validate_first_name(self, value):
        return validate_name(value, "First name")
    
    def validate_last_name(self, value):
        return validate_name(value, "Last name")
    
    def validate(self, data):
        # Check if user with this phone already exists
        if 'phone' in data:
            normalized_phone = normalize_phone_number(data['phone'])
            if User.objects.filter(phone=normalized_phone).exists():
                raise serializers.ValidationError({
                    "phone": "User with this phone number already exists"
                })
            data['phone'] = normalized_phone
        
        email = data.get('email')
        if email and User.objects.filter(email=email).exists():
            raise serializers.ValidationError({
                "email": "User with this email already exists"
            })
        
        return data
    
    def create(self, validated_data):
        phone = validated_data.pop('phone')
        first_name = validated_data.pop('first_name')
        middle_name = validated_data.pop('middle_name', None)
        last_name = validated_data.pop('last_name')
        email = validated_data.pop('email', None)
        password = validated_data.pop('password', None)
        user_data = {
            'phone': phone,
            'first_name': first_name,
            'last_name': last_name,
            'email': email,
            'role': 'FARMER',
        }
        if middle_name:
            user_data['middle_name'] = middle_name
        
        user = User(**user_data)
        if password:
            user.set_password(password)
        else:
            import random
            import string
            random_password = ''.join(random.choices(string.ascii_letters + string.digits, k=12))
            user.set_password(random_password)
        user.save()

        owner = Owner.objects.create(
            user=user,
            **validated_data
        )
        
        return owner

class AnimalSerializer(serializers.ModelSerializer):
    owner_name = serializers.SerializerMethodField()
    owner_phone = serializers.CharField(source='owner.user.phone', read_only=True)
    owner_profile_info = OwnerListSerializer(source='owner', read_only=True)
    
    class Meta:
        model = Livestock
        fields = [
            'id', 'animal_id', 'name', 'type', 'color', 'photo', 
            'owner', 'owner_name', 'owner_phone', 'owner_profile_info',
            'status', 'notes', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'animal_id', 'created_at', 'updated_at']
        extra_kwargs = {
            'name': {'required': True},
            'owner': {'required': True},
        }
    
    def get_owner_name(self, obj):
        """Get full name from owner's user"""
        if obj.owner and obj.owner.user:
            user = obj.owner.user
            parts = [user.first_name]
            if user.middle_name:
                parts.append(user.middle_name)
            if user.last_name:
                parts.append(user.last_name)
            return ' '.join(parts)
        return ''

class AnimalCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Livestock
        fields = ['name', 'type', 'color', 'photo', 'owner', 'notes']
        extra_kwargs = {
            'name': {'required': True},
            'owner': {'required': True},
        }
    
    def validate_name(self, value):
        return validate_name(value, "Animal name")
    
    def create(self, validated_data):
        owner_id = validated_data.get('owner')
        count = Livestock.objects.filter(owner=owner_id).count() + 1
        validated_data['animal_id'] = f"ANIMAL-{owner_id}-{count:04d}"
        
        return super().create(validated_data)

class GPSDeviceSerializer(serializers.ModelSerializer):
    animal_name = serializers.CharField(source='animal.name', read_only=True)
    owner_name = serializers.SerializerMethodField()
    
    class Meta:
        model = GPSDevice
        fields = [
            'id', 'device_id', 'animal', 'animal_name',
            'owner_name', 'status', 'battery_level', 'last_online', 
            'created_at'
        ]
        read_only_fields = ['id', 'created_at']
    
    def get_owner_name(self, obj):
        if obj.animal and obj.animal.owner and obj.animal.owner.user:
            return get_full_name(obj.animal.owner.user)
        return ''

class GPSDeviceCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = GPSDevice
        fields = ['device_id', 'animal']
        extra_kwargs = {
            'device_id': {'required': True},
            'animal': {'required': True},
        }

class LocationSerializer(serializers.ModelSerializer):
    animal_name = serializers.CharField(source='animal.name', read_only=True)
    
    class Meta:
        model = Location
        fields = ['id', 'animal', 'animal_name', 'latitude', 'longitude', 
                  'speed', 'timestamp']
        read_only_fields = ['id', 'timestamp']

class LocationCreateSerializer(serializers.ModelSerializer):
    device = serializers.CharField(write_only=True)

    class Meta:
        model = Location
        fields = ['device', 'latitude', 'longitude', 'speed']

    def validate(self, attrs):
        device_id = attrs.get("device")

        try:
            device = GPSDevice.objects.get(device_id=device_id)
        except GPSDevice.DoesNotExist:
            raise serializers.ValidationError({
                "device": "GPS device not found."
            })

        if device.animal is None:
            raise serializers.ValidationError({
                "device": "This GPS device is not assigned to any animal."
            })

        attrs["gps_device"] = device
        return attrs

    def create(self, validated_data):
        device = validated_data.pop("gps_device")
        validated_data.pop("device", None)

        location = Location.objects.create(
            animal=device.animal,
            device=device,
            latitude=validated_data["latitude"],
            longitude=validated_data["longitude"],
            speed=validated_data.get("speed", 0)
        )

        return location
    
class OwnershipTransferSerializer(serializers.ModelSerializer):
    from_user_name = serializers.SerializerMethodField()
    to_user_name = serializers.SerializerMethodField()
    animal_name = serializers.CharField(source='animal.name', read_only=True)
    animal_id = serializers.IntegerField(source='animal.id', read_only=True)
    
    class Meta:
        model = OwnershipTransfer
        fields = [
            'id', 'animal', 'animal_id', 'animal_name', 
            'from_user', 'from_user_name',
            'to_user', 'to_user_name', 'status', 'initiated_at',
            'confirmed_at', 'expiry_date', 'notes'
        ]
        read_only_fields = ['id', 'initiated_at', 'confirmed_at', 'from_user', 'status']
        extra_kwargs = {
            'animal': {'required': True},
            'to_user': {'required': True},
            'notes': {'required': False},
            'expiry_date': {'required': False},
        }
    
    def get_from_user_name(self, obj):
        return get_full_name(obj.from_user)
    
    def get_to_user_name(self, obj):
        return get_full_name(obj.to_user)

class OwnershipTransferCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = OwnershipTransfer
        fields = ['animal', 'to_user', 'notes', 'expiry_date']
        extra_kwargs = {
            'animal': {'required': True},
            'to_user': {'required': True},
            'notes': {'required': False},
            'expiry_date': {'required': False},
        }
    
    def validate(self, data):
        animal = data.get('animal')
        to_user = data.get('to_user')

        if not animal:
            raise serializers.ValidationError({
                "animal": "Animal is required"
            })

        if animal.owner == to_user:
            raise serializers.ValidationError({
                "to_user": "You cannot transfer ownership to yourself"
            })
        
        # Check if recipient is a farmer
        if to_user.role != 'FARMER':
            raise serializers.ValidationError({
                "to_user": "Recipient must be a farmer"
            })

        if OwnershipTransfer.objects.filter(
            animal=animal, 
            status='PENDING'
        ).exists():
            raise serializers.ValidationError({
                "animal": "There is already a pending transfer for this animal"
            })
        
        return data
    
    def create(self, validated_data):
        validated_data['from_user'] = self.context['request'].user
        return super().create(validated_data)


class AlertSerializer(serializers.ModelSerializer):
    animal_name = serializers.CharField(source='animal.name', read_only=True)
    user_name = serializers.SerializerMethodField()
    
    class Meta:
        model = Alert
        fields = [
            'id', 'title', 'message', 'alert_type', 'animal', 'animal_name',
            'user', 'user_name', 'is_read', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']
    
    def get_user_name(self, obj):
        return get_full_name(obj.user)

class AlertCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Alert
        fields = ['title', 'message', 'alert_type', 'animal']
        extra_kwargs = {
            'title': {'required': True},
            'message': {'required': True},
            'alert_type': {'required': True},
        }
    
    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)

class AlertUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Alert
        fields = ['is_read']
        extra_kwargs = {
            'is_read': {'required': True},
        }


class BroadcastMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.SerializerMethodField()
    
    class Meta:
        model = BroadcastMessage
        fields = ['id', 'title', 'message', 'sender', 'sender_name', 
                  'recipients', 'sent_at']
        read_only_fields = ['id', 'sent_at']
    
    def get_sender_name(self, obj):
        return get_full_name(obj.sender)

class BroadcastMessageCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = BroadcastMessage
        fields = ['title', 'message', 'recipients']
        extra_kwargs = {
            'title': {'required': True},
            'message': {'required': True},
            'recipients': {'required': False},
        }
    
    def create(self, validated_data):
        validated_data['sender'] = self.context['request'].user
        return super().create(validated_data)

class LivestockReportSerializer(serializers.ModelSerializer):
    generated_by_name = serializers.SerializerMethodField()
    
    class Meta:
        model = LivestockReport
        fields = [
            'id', 'report_type', 'generated_by', 'generated_by_name',
            'start_date', 'end_date', 'total_animals', 'animals_by_type',
            'animals_by_status', 'stolen_reported', 'generated_at'
        ]
        read_only_fields = ['id', 'generated_at']
    
    def get_generated_by_name(self, obj):
        return get_full_name(obj.generated_by)

class LivestockReportCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = LivestockReport
        fields = ['report_type', 'start_date', 'end_date']
        extra_kwargs = {
            'report_type': {'required': True},
            'start_date': {'required': True},
            'end_date': {'required': True},
        }
    
    def create(self, validated_data):
        validated_data['generated_by'] = self.context['request'].user
        
        report_type = validated_data.get('report_type')
        start_date = validated_data.get('start_date')
        end_date = validated_data.get('end_date')
        
        livestock = Livestock.objects.filter(created_at__range=[start_date, end_date])
        
        validated_data['total_animals'] = livestock.count()
        
        animals_by_type = livestock.values('type').annotate(count=Count('id'))
        validated_data['animals_by_type'] = animals_by_type
        
        animals_by_status = livestock.values('status').annotate(count=Count('id'))
        validated_data['animals_by_status'] = animals_by_status
        
        if report_type == 'THEFT':
            validated_data['stolen_reported'] = livestock.filter(status='STOLEN').count()
        else:
            validated_data['stolen_reported'] = 0
        
        return super().create(validated_data)

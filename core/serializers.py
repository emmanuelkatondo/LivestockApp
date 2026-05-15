from rest_framework import serializers
from django.contrib.auth import authenticate
from .models import *

def normalize_phone_number(value):
    phone = str(value).strip().replace(" ", "")
    if phone.startswith('+'):
        phone = phone[1:]
    if phone.startswith('0'):
        phone = '255' + phone[1:]

    if not phone.startswith('255') or len(phone) != 12 or not phone.isdigit():
        raise serializers.ValidationError("Phone number must be in format 255XXXXXXXXX")

    return phone

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'phone', 'first_name', 'email', 'role', 'location', 'profile_picture', 'date_joined']
        read_only_fields = ['id', 'date_joined']

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    confirm_password = serializers.CharField(write_only=True)
    
    class Meta:
        model = User
        fields = ['phone', 'first_name', 'email', 'password', 'confirm_password', 'location']
    
    def validate(self, data):
        if data['password'] != data['confirm_password']:
            raise serializers.ValidationError({"confirm_password": "Passwords do not match"})
        return data
    
    def validate_phone(self, value):
        if not value:
            raise serializers.ValidationError("Phone number is required")
        return normalize_phone_number(value)
    
    def create(self, validated_data):
        validated_data.pop('confirm_password')
        password = validated_data.pop('password')
        
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user

class LoginSerializer(serializers.Serializer):
    phone = serializers.CharField()
    password = serializers.CharField(write_only=True)
    
    def validate(self, data):
        phone = normalize_phone_number(data['phone'])
        
        user = authenticate(phone=phone, password=data['password'])
        if not user:
            user = authenticate(phone=f'+{phone}', password=data['password'])
        if not user:
            raise serializers.ValidationError("Invalid phone number or password")
        if not user.is_active:
            raise serializers.ValidationError("Account is disabled")
        return {'user': user}

#  OWNER SERIALIZER 
class OwnerSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.first_name', read_only=True)
    user_phone = serializers.CharField(source='user.phone', read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)
    user_location = serializers.CharField(source='user.location', read_only=True)
    
    class Meta:
        model = Owner
        fields = [
            'id', 'user', 'user_name', 'user_phone', 'user_email', 'user_location',
            'farm_name', 'farm_location', 'national_id', 'registration_number',
            'alternative_phone', 'emergency_contact', 'total_animals',
            'total_gps_devices', 'is_verified', 'verified_at', 'notes',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'registration_number', 'total_animals', 
                           'total_gps_devices', 'created_at', 'updated_at']

class OwnerListSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.first_name', read_only=True)
    user_phone = serializers.CharField(source='user.phone', read_only=True)
    
    class Meta:
        model = Owner
        fields = ['id', 'user', 'user_name', 'user_phone', 'farm_name','total_animals', 'is_verified']


class AnimalSerializer(serializers.ModelSerializer):
    owner_name = serializers.CharField(source='owner.first_name', read_only=True)
    owner_profile_info = OwnerListSerializer(source='owner_profile', read_only=True) 
    
    class Meta:
        model = Livestock
        fields = ['id', 'animal_id', 'name', 'type', 'color', 'photo', 'owner', 
                  'owner_name', 'owner_profile_info', 'status', 'notes', 
                  'created_at', 'updated_at']
        read_only_fields = ['id', 'animal_id', 'created_at', 'updated_at', 'owner']
        extra_kwargs = {
            'name': {'required': True},
        }

class GPSDeviceSerializer(serializers.ModelSerializer):
    animal_name = serializers.CharField(source='animal.name', read_only=True)
    
    class Meta:
        model = GPSDevice
        fields = ['id', 'device_id', 'qr_code', 'animal', 'animal_name', 'status', 
                  'battery_level', 'last_online', 'created_at']
        read_only_fields = ['id', 'created_at']

class LocationSerializer(serializers.ModelSerializer):
    animal_name = serializers.CharField(source='animal.name', read_only=True)
    
    class Meta:
        model = Location
        fields = ['id', 'animal', 'animal_name', 'latitude', 'longitude', 'speed', 'timestamp']
        read_only_fields = ['id', 'timestamp']

class OwnershipTransferSerializer(serializers.ModelSerializer):
    from_user_name = serializers.CharField(source='from_user.first_name', read_only=True)
    to_user_name = serializers.CharField(source='to_user.first_name', read_only=True)
    animal_name = serializers.CharField(source='animal.name', read_only=True)
    
    class Meta:
        model = OwnershipTransfer
        fields = ['id', 'animal', 'animal_name', 'from_user', 'from_user_name', 
                  'to_user', 'to_user_name', 'status', 'initiated_at', 
                  'confirmed_at', 'expiry_date', 'notes']
        read_only_fields = ['id', 'initiated_at', 'confirmed_at', 'from_user', 'status']
        extra_kwargs = {
            'animal': {'required': True},
            'to_user': {'required': True},
            'notes': {'required': False},
            'expiry_date': {'required': False},  
        }

class AlertSerializer(serializers.ModelSerializer):
    animal_name = serializers.CharField(source='animal.name', read_only=True)
    user_name = serializers.CharField(source='user.first_name', read_only=True)
    
    class Meta:
        model = Alert
        fields = ['id', 'title', 'message', 'alert_type', 'animal', 'animal_name', 
                  'user', 'user_name', 'is_read', 'created_at']
        read_only_fields = ['id', 'created_at']

class BroadcastMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source='sender.first_name', read_only=True)
    
    class Meta:
        model = BroadcastMessage
        fields = ['id', 'title', 'message', 'sender', 'sender_name', 'recipients', 'sent_at']
        read_only_fields = ['id', 'sent_at']

class LivestockReportSerializer(serializers.ModelSerializer):
    generated_by_name = serializers.CharField(source='generated_by.first_name', read_only=True)
    
    class Meta:
        model = LivestockReport
        fields = ['id', 'report_type', 'generated_by', 'generated_by_name', 
                  'start_date', 'end_date', 'total_animals', 'animals_by_type', 
                  'animals_by_status', 'stolen_reported', 'generated_at']
        read_only_fields = ['id', 'generated_at']

from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models
from django.utils import timezone
from django.core.validators import RegexValidator, MinValueValidator, MaxValueValidator

#USER MANAGER 
class UserManager(BaseUserManager):
    def create_user(self, phone, first_name, password=None, **extra_fields):
        if not phone:
            raise ValueError('Phone number is required')
        if not first_name:
            raise ValueError('Full name is required')
        
        user = self.model(phone=phone, first_name=first_name, **extra_fields)
        if password:
            user.set_password(password)
        user.save(using=self._db)
        return user
    
    def create_superuser(self, phone, first_name, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('role', User.Role.AG_OFFICER)
        return self.create_user(phone, first_name, password, **extra_fields)


#USER MODEL
class User(AbstractBaseUser, PermissionsMixin):
    class Role(models.TextChoices):
        FARMER = 'FARMER', 'Farmer'
        AG_OFFICER = 'AG_OFFICER', 'Agricultural Officer'
        POLICE = 'POLICE', 'Police Officer'
    
    phone_regex = RegexValidator(
        regex=r'^(0|\+?255)\d{9}$', 
        message="Phone number must be format: 255XXXXXXXXX"
    )
    
    phone = models.CharField(max_length=13, unique=True, validators=[phone_regex])
    first_name = models.CharField(max_length=255)
    email = models.EmailField(blank=True, null=True)
    role = models.CharField(max_length=20, choices=Role.choices, default=Role.FARMER)
    location = models.CharField(max_length=255, blank=True, null=True)
    profile_picture = models.ImageField(upload_to='profile_pictures/', blank=True, null=True)
    
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(default=timezone.now)
    last_login = models.DateTimeField(null=True, blank=True)
    
    push_notifications = models.BooleanField(default=True)
    sms_notifications = models.BooleanField(default=False)
    
    objects = UserManager()
    
    USERNAME_FIELD = 'phone'
    REQUIRED_FIELDS = ['first_name']
    
    def __str__(self):
        return f"{self.first_name} ({self.phone})"
    
    @property
    def is_farmer(self):
        return self.role == self.Role.FARMER
    
    @property
    def is_ag_officer(self):
        return self.role == self.Role.AG_OFFICER
    
    @property
    def is_police(self):
        return self.role == self.Role.POLICE


# OWNER MODEL 
class Owner(models.Model):
    user = models.OneToOneField(
        User, 
        on_delete=models.CASCADE, 
        related_name='owner_profile',
        limit_choices_to={'role': User.Role.FARMER}
    )
 
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Mfugaji'
        verbose_name_plural = 'Wafugaji'
    
    
    def __str__(self):
        return f"{self.user.first_name}"
    
    @property
    def full_name(self):
        return self.user.first_name
    
    @property
    def phone(self):
        return self.user.phone
    
    @property
    def email(self):
        return self.user.email
    
    @property
    def location(self):
        return self.user.location
    
    @property
    def profile_picture(self):
        return self.user.profile_picture


# LIVESTOCK MODEL 
class Livestock(models.Model):
    class AnimalType(models.TextChoices):
        CATTLE = 'CATTLE', 'Ng\'ombe'
        GOAT = 'GOAT', 'Mbuzi'
        SHEEP = 'SHEEP', 'Kondoo'
        OTHER = 'OTHER', 'Nyingine'
    
    class AnimalStatus(models.TextChoices):
        ACTIVE = 'ACTIVE', 'Active'
        SOLD = 'SOLD', 'Imeuzwa'
        SLAUGHTERED = 'SLAUGHTERED', 'Imechinjwa'
        DEAD = 'DEAD', 'Imekufa'
        STOLEN = 'STOLEN', 'Imeibwa'
    
    animal_id = models.CharField(max_length=50, unique=True, blank=True)
    name = models.CharField(max_length=100)
    type = models.CharField(max_length=20, choices=AnimalType.choices, default=AnimalType.CATTLE)
    color = models.CharField(max_length=100, blank=True, null=True)
    photo = models.ImageField(upload_to='animals/', blank=True, null=True)

    owner = models.ForeignKey(
        Owner, 
        on_delete=models.CASCADE, 
        related_name='animals'
    )
    
    status = models.CharField(max_length=20, choices=AnimalStatus.choices, default=AnimalStatus.ACTIVE)
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def save(self, *args, **kwargs):
        if not self.animal_id:
            year = timezone.now().year
            prefix = self.type[:3].upper()
            last_animal = Livestock.objects.filter(type=self.type).order_by('-id').first()
            if last_animal and last_animal.animal_id:
                try:
                    last_num = int(last_animal.animal_id[-3:])
                    new_num = last_num + 1
                except (ValueError, IndexError):
                    new_num = 1
            else:
                new_num = 1
            self.animal_id = f"{prefix}{year}{new_num:03d}"
        super().save(*args, **kwargs)
    
    @property
    def owner_name(self):
        return self.owner.user.first_name
    
    @property
    def owner_phone(self):
        return self.owner.user.phone
    
    @property
    def owner_email(self):
        return self.owner.user.email
    
    @property
    def owner_location(self):
        return self.owner.user.location
    
    def __str__(self):
        return f"{self.animal_id} - {self.name}"
    
    class Meta:
        ordering = ['-created_at']


#  GPS DEVICE MODEL 
class GPSDevice(models.Model):
    class DeviceStatus(models.TextChoices):
        ACTIVE = 'ACTIVE', 'Active'
        INACTIVE = 'INACTIVE', 'Inactive'
        MAINTENANCE = 'MAINTENANCE', 'Maintenance'
        LOST = 'LOST', 'Lost'
    
    device_id = models.CharField(max_length=100, unique=True)
    qr_code = models.CharField(max_length=255, unique=True, blank=True,null=True)
    animal = models.OneToOneField(
        Livestock, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name='gps_device'
    )
    status = models.CharField(max_length=20, choices=DeviceStatus.choices, default=DeviceStatus.ACTIVE)
    battery_level = models.IntegerField(default=100, validators=[MinValueValidator(0), MaxValueValidator(100)])
    last_online = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        animal_name = self.animal.name if self.animal else "Unassigned"
        return f"Device {self.device_id} - {animal_name}"


# LOCATION MODEL 
class Location(models.Model):
    animal = models.ForeignKey(Livestock, on_delete=models.CASCADE, related_name='locations')
    device = models.ForeignKey(GPSDevice, on_delete=models.SET_NULL, null=True, related_name='locations')
    latitude = models.DecimalField(max_digits=10, decimal_places=7)
    longitude = models.DecimalField(max_digits=10, decimal_places=7)
    speed = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    timestamp = models.DateTimeField(default=timezone.now)
    
    class Meta:
        ordering = ['-timestamp']
    
    def __str__(self):
        return f"{self.animal.name} at ({self.latitude}, {self.longitude})"


#OWNERSHIP TRANSFER MODEL
class OwnershipTransfer(models.Model):
    class TransferStatus(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        CONFIRMED = 'CONFIRMED', 'Confirmed'
        REJECTED = 'REJECTED', 'Rejected'
        EXPIRED = 'EXPIRED', 'Expired'
    
    animal = models.ForeignKey(Livestock, on_delete=models.CASCADE, related_name='transfers')
    from_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='transfers_sent')
    to_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='transfers_received')
    status = models.CharField(max_length=20, choices=TransferStatus.choices, default=TransferStatus.PENDING)
    initiated_at = models.DateTimeField(auto_now_add=True)
    confirmed_at = models.DateTimeField(null=True, blank=True)
    expiry_date = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True, null=True)
    
    def save(self, *args, **kwargs):
        if not self.expiry_date:
            self.expiry_date = timezone.now() + timezone.timedelta(days=7)
        super().save(*args, **kwargs)
    
    def __str__(self):
        return f"{self.animal.name}: {self.from_user.first_name} -> {self.to_user.first_name}"


#ALERT MODEL
class Alert(models.Model):
    class AlertType(models.TextChoices):
        LOST = 'LOST', 'Lost Animal'
        THEFT = 'THEFT', 'Theft Reported'
        GENERAL = 'GENERAL', 'General'
    
    title = models.CharField(max_length=255)
    message = models.TextField()
    alert_type = models.CharField(max_length=20, choices=AlertType.choices)
    animal = models.ForeignKey(Livestock, on_delete=models.CASCADE, null=True, blank=True, related_name='alerts')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='alerts', null=True, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.alert_type}: {self.title}"


#BROADCAST MESSAGE MODEL
class BroadcastMessage(models.Model):
    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name='broadcasts_sent')
    title = models.CharField(max_length=255)
    message = models.TextField()
    recipients = models.ManyToManyField(User, related_name='broadcasts_received', blank=True)
    sent_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.title} - {self.sender.first_name}"


# LIVESTOCK REPORT MODEL
class LivestockReport(models.Model):
    class ReportType(models.TextChoices):
        POPULATION = 'POPULATION', 'Population Report'
        THEFT = 'THEFT', 'Theft Report'
    
    generated_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reports')
    report_type = models.CharField(max_length=20, choices=ReportType.choices)
    start_date = models.DateTimeField()
    end_date = models.DateTimeField()
    total_animals = models.IntegerField(default=0)
    animals_by_type = models.JSONField(default=dict)
    animals_by_status = models.JSONField(default=dict)
    stolen_reported = models.IntegerField(default=0)
    generated_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.report_type} - {self.generated_at.date()}"



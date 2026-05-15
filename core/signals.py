# core/signals.py
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import User, Owner

@receiver(post_save, sender=User)
def create_owner_profile(sender, instance, created, **kwargs):
    """Create Owner profile automatically when a FARMER user is created"""
    if created and instance.role == User.Role.FARMER:
        Owner.objects.get_or_create(user=instance)

@receiver(post_save, sender=User)
def save_owner_profile(sender, instance, **kwargs):
    """Save Owner profile when user is saved"""
    if instance.role == User.Role.FARMER:
        try:
            if hasattr(instance, 'owner_profile'):
                instance.owner_profile.save()
        except Owner.DoesNotExist:
            Owner.objects.create(user=instance)
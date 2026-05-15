# core/urls.py
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import *

router = DefaultRouter()
router.register(r'users', UserViewSet, basename='user')  # Add basename
router.register(r'animals', AnimalViewSet, basename='animal')
router.register(r'devices', GPSDeviceViewSet, basename='device')
router.register(r'locations', LocationViewSet, basename='location')
router.register(r'transfers', OwnershipTransferViewSet, basename='transfer')
router.register(r'alerts', AlertViewSet, basename='alert')
router.register(r'broadcasts', BroadcastMessageViewSet, basename='broadcast')
router.register(r'reports', LivestockReportViewSet, basename='report')
router.register(r'owners', OwnerViewSet, basename='owner')
urlpatterns = [
    path('', include(router.urls)),
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
]
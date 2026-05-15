from django.contrib import admin
from .models import *

admin.site.register(User)
admin.site.register(Livestock)
admin.site.register(GPSDevice)
admin.site.register(Location)
admin.site.register(Owner)
admin.site.register(OwnershipTransfer)
admin.site.register(Alert)
admin.site.register(BroadcastMessage)
admin.site.register(LivestockReport)
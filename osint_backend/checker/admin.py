from django.contrib import admin
from django.contrib.auth.models import User as AuthUser, Group

# Remove the default Authentication and Authorization section from the admin panel
try:
    admin.site.unregister(AuthUser)
    admin.site.unregister(Group)
except admin.sites.NotRegistered:
    pass

from .models import (
    User,
    UserFeedback,
    UsersInputLogs,
    EmailSearchResults,
    PhoneSearchResults,
    UsernameSearchResults,
)

@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ('user_id', 'first_name', 'last_name', 'email', 'phone', 'is_verified', 'created_at')
    list_filter = ('is_verified',)
    search_fields = ('email', 'phone', 'first_name', 'last_name')

@admin.register(UsersInputLogs)
class UsersInputLogsAdmin(admin.ModelAdmin):
    list_display = ('log_id', 'search_type', 'search_query', 'user_ip', 'status')
    list_filter = ('search_type', 'status')
    search_fields = ('search_query', 'user_ip')

@admin.register(UserFeedback)
class UserFeedbackAdmin(admin.ModelAdmin):
    list_display = ('feedback_id', 'user', 'subject', 'feedback_type', 'submitted_at')
    list_filter = ('feedback_type', 'status')
    search_fields = ('subject',)

@admin.register(EmailSearchResults)
class EmailSearchResultsAdmin(admin.ModelAdmin):
    list_display = ('id', 'log', 'email', 'is_deliverable', 'breach_count')
    list_filter = ('is_deliverable',)
    search_fields = ('email',)

@admin.register(PhoneSearchResults)
class PhoneSearchResultsAdmin(admin.ModelAdmin):
    list_display = ('id', 'log', 'phone_number', 'carrier', 'line_type', 'location')
    list_filter = ('line_type',)
    search_fields = ('phone_number', 'carrier', 'location')

@admin.register(UsernameSearchResults)
class UsernameSearchResultsAdmin(admin.ModelAdmin):
    list_display = ('id', 'log', 'username', 'platform_name', 'is_registered')
    list_filter = ('is_registered', 'platform_name')
    search_fields = ('username', 'platform_name', 'profile_url')

# This is an auto-generated Django model module.
# You'll have to do the following manually to clean this up:
#   * Rearrange models' order
#   * Make sure each model has one field with primary_key=True
#   * Make sure each ForeignKey and OneToOneField has `on_delete` set to the desired behavior
#   * Remove `managed = False` lines if you wish to allow Django to create, modify, and delete the table
# Feel free to rename the models, but don't rename db_table values or field names.
from django.db import models


class Users(models.Model):
    id = models.BigAutoField(primary_key=True)
    password = models.CharField(max_length=128)
    last_login = models.DateTimeField(blank=True, null=True)
    is_superuser = models.IntegerField()
    first_name = models.CharField(max_length=150)
    last_name = models.CharField(max_length=150)
    is_staff = models.IntegerField()
    is_active = models.IntegerField()
    date_joined = models.DateTimeField()
    email = models.CharField(unique=True, max_length=254)
    phone = models.CharField(unique=True, max_length=15)
    otp_code = models.CharField(max_length=4, blank=True, null=True)
    is_otp_verified = models.IntegerField()
    created_at = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'users'


class ScanRequests(models.Model):
    id = models.BigAutoField(primary_key=True)
    input_value = models.CharField(max_length=255, blank=True, null=True)
    input_type = models.CharField(max_length=10)
    face_path = models.CharField(max_length=100, blank=True, null=True)
    status = models.CharField(max_length=15)
    created_at = models.DateTimeField()
    user = models.ForeignKey(Users, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'scan_requests'


class BreachResults(models.Model):
    id = models.BigAutoField(primary_key=True)
    breach_name = models.CharField(max_length=255)
    leaked_data = models.JSONField()
    risk_score = models.IntegerField()
    severity = models.CharField(max_length=15)
    found_at = models.DateTimeField()
    scan_request = models.ForeignKey(ScanRequests, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'breach_results'


class ContinuousMonitoring(models.Model):
    id = models.BigAutoField(primary_key=True)
    target_value = models.CharField(max_length=255)
    target_type = models.CharField(max_length=10)
    frequency_minutes = models.IntegerField()
    is_active = models.IntegerField()
    last_checked_at = models.DateTimeField()
    user = models.ForeignKey(Users, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'continuous_monitoring'


class Reports(models.Model):
    id = models.BigAutoField(primary_key=True)
    summary = models.TextField()
    report_format = models.CharField(max_length=10)
    report_path = models.CharField(max_length=100)
    created_at = models.DateTimeField()
    user = models.ForeignKey(Users, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'reports'


class Alerts(models.Model):
    id = models.BigAutoField(primary_key=True)
    message = models.TextField()
    channel = models.CharField(max_length=10)
    is_read = models.IntegerField()
    created_at = models.DateTimeField()
    breach_result = models.ForeignKey(BreachResults, models.DO_NOTHING, blank=True, null=True)
    user = models.ForeignKey(Users, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'alerts'


class UserFeedback(models.Model):
    id = models.BigAutoField(primary_key=True)
    category = models.CharField(max_length=100)
    message = models.TextField()
    status = models.CharField(max_length=15)
    created_at = models.DateTimeField()
    user = models.ForeignKey(Users, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'user_feedback'

"""
checker/models.py
-----------------
Django ORM models mapping exactly to the custom MySQL data dictionary.
"""
from django.db import models # type: ignore
from django.utils import timezone # type: ignore

# ---------------------------------------------------------------------------
# users
# ---------------------------------------------------------------------------
class User(models.Model):
    user_id       = models.AutoField(primary_key=True)
    first_name    = models.CharField(max_length=50)
    last_name     = models.CharField(max_length=50)
    email         = models.CharField(unique=True, max_length=100)
    phone         = models.CharField(unique=True, max_length=20)
    password_hash = models.CharField(max_length=255)
    otp_code      = models.CharField(max_length=6, blank=True, null=True)
    otp_expiry    = models.DateTimeField(blank=True, null=True)
    is_verified   = models.BooleanField(default=False)
    created_at    = models.DateTimeField(default=timezone.now)

    class Meta:
        managed = True
        db_table = 'users'

    def __str__(self):
        return f'{self.first_name} {self.last_name} <{self.email}>'

# ---------------------------------------------------------------------------
# scan_requests
# ---------------------------------------------------------------------------
class ScanRequest(models.Model):
    INPUT_TYPE_CHOICES = [('email', 'Email'), ('phone', 'Phone'), ('face', 'Face')]
    STATUS_CHOICES = [
        ('pending', 'Pending'), ('verifying', 'Verifying'), ('verified', 'Verified'),
        ('scanning', 'Scanning'), ('completed', 'Completed'), ('not_found', 'Not Found'),
        ('error', 'Error'),
    ]

    input_id     = models.AutoField(primary_key=True)
    user         = models.ForeignKey(User, on_delete=models.CASCADE, db_column='user_id')
    input_type   = models.CharField(max_length=10, choices=INPUT_TYPE_CHOICES)
    input_value  = models.CharField(max_length=255, blank=True, null=True)
    face_path    = models.CharField(max_length=500, blank=True, null=True)
    status       = models.CharField(max_length=15, choices=STATUS_CHOICES, default='pending')
    requested_at = models.DateTimeField(default=timezone.now)
    updated_at   = models.DateTimeField(blank=True, null=True, auto_now=True)

    class Meta:
        managed = True
        db_table = 'scan_requests'

    def __str__(self):
        return f'Scan #{self.input_id} - {self.status}'

# ---------------------------------------------------------------------------
# breach_results
# ---------------------------------------------------------------------------
class BreachResult(models.Model):
    RISK_LEVEL_CHOICES = [('low', 'Low'), ('medium', 'Medium'), ('high', 'High')]

    result_id   = models.AutoField(primary_key=True)
    input       = models.ForeignKey(ScanRequest, on_delete=models.CASCADE, db_column='input_id')
    site_name   = models.CharField(max_length=255)
    site_url    = models.CharField(max_length=1000)
    risk_level  = models.CharField(max_length=10, choices=RISK_LEVEL_CHOICES, default='medium')
    leaked_data = models.TextField()
    detected_at = models.DateTimeField(default=timezone.now)

    class Meta:
        managed = True
        db_table = 'breach_results'

    def __str__(self):
        return f'Breach #{self.result_id} - {self.site_name}'

# ---------------------------------------------------------------------------
# continuous_monitoring
# ---------------------------------------------------------------------------
class ContinuousMonitoring(models.Model):
    INPUT_TYPE_CHOICES = [('email', 'Email'), ('phone', 'Phone'), ('face', 'Face')]
    STATUS_CHOICES = [('active', 'Active'), ('paused', 'Paused'), ('stopped', 'Stopped')]

    monitor_id        = models.AutoField(primary_key=True)
    user              = models.ForeignKey(User, on_delete=models.CASCADE, db_column='user_id')
    input_type        = models.CharField(max_length=10, choices=INPUT_TYPE_CHOICES)
    input_value       = models.CharField(max_length=255, blank=True, null=True)
    face_path         = models.CharField(max_length=500, blank=True, null=True)
    status            = models.CharField(max_length=10, choices=STATUS_CHOICES, default='active')
    frequency_minutes = models.IntegerField(default=60)
    last_checked_at   = models.DateTimeField(blank=True, null=True)
    created_at        = models.DateTimeField(default=timezone.now)
    updated_at        = models.DateTimeField(blank=True, null=True, auto_now=True)

    class Meta:
        managed = True
        db_table = 'continuous_monitoring'

    def __str__(self):
        return f'Monitor #{self.monitor_id}'

# ---------------------------------------------------------------------------
# reports
# ---------------------------------------------------------------------------
class Report(models.Model):
    RISK_CHOICES = [('low', 'Low'), ('medium', 'Medium'), ('high', 'High')]
    FORMAT_CHOICES = [('pdf', 'PDF'), ('html', 'HTML'), ('json', 'JSON')]

    report_id     = models.AutoField(primary_key=True)
    input         = models.ForeignKey(ScanRequest, on_delete=models.CASCADE, db_column='input_id')
    result_count  = models.IntegerField(default=0)
    highest_risk  = models.CharField(max_length=10, choices=RISK_CHOICES, default='low')
    report_name   = models.CharField(max_length=25)
    report_format = models.CharField(max_length=10, choices=FORMAT_CHOICES, default='pdf')
    report_path   = models.CharField(max_length=500)
    summary       = models.TextField(blank=True, null=True)
    generated_at  = models.DateTimeField(default=timezone.now)
    viewed_at     = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = True
        db_table = 'reports'

    def __str__(self):
        return f'Report #{self.report_id} - {self.report_name}'

# ---------------------------------------------------------------------------
# alerts
# ---------------------------------------------------------------------------
class Alert(models.Model):
    CHANNEL_CHOICES = [('in_app', 'In App'), ('email', 'Email')]
    SEVERITY_CHOICES = [('low', 'Low'), ('medium', 'Medium'), ('high', 'High')]
    STATUS_CHOICES = [('pending', 'Pending'), ('sent', 'Sent'), ('failed', 'Failed'), ('read', 'Read')]

    alert_id      = models.AutoField(primary_key=True)
    user          = models.ForeignKey(User, on_delete=models.CASCADE, db_column='user_id')
    monitor       = models.ForeignKey(ContinuousMonitoring, on_delete=models.CASCADE, blank=True, null=True, db_column='monitor_id')
    result        = models.ForeignKey(BreachResult, on_delete=models.CASCADE, blank=True, null=True, db_column='result_id')
    channel       = models.CharField(max_length=10, choices=CHANNEL_CHOICES, default='in_app')
    message       = models.TextField()
    severity      = models.CharField(max_length=10, choices=SEVERITY_CHOICES, default='medium')
    status        = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    sent_at       = models.DateTimeField(blank=True, null=True)
    read_at       = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = True
        db_table = 'alerts'

    def __str__(self):
        return f'Alert #{self.alert_id}'

# ---------------------------------------------------------------------------
# user_feedback
# ---------------------------------------------------------------------------
class UserFeedback(models.Model):
    TYPE_CHOICES = [('bug', 'Bug'), ('suggestion', 'Suggestion'), ('question', 'Question'), ('other', 'Other')]
    STATUS_CHOICES = [('new', 'New'), ('in_progress', 'In Progress'), ('resolved', 'Resolved'), ('archived', 'Archived')]

    feedback_id   = models.AutoField(primary_key=True)
    user          = models.ForeignKey(User, on_delete=models.CASCADE, db_column='user_id')
    subject       = models.CharField(max_length=100)
    message       = models.TextField()
    feedback_type = models.CharField(max_length=15, choices=TYPE_CHOICES, default='suggestion')
    status        = models.CharField(max_length=15, choices=STATUS_CHOICES, default='new')
    submitted_at  = models.DateTimeField(default=timezone.now)
    resolved_at   = models.DateTimeField(blank=True, null=True)

    class Meta:
        managed = True
        db_table = 'user_feedback'

    def __str__(self):
        return f'Feedback #{self.feedback_id}'

# ==============================================================================
# OSINT2 Specific Models
# ==============================================================================

class UsersInputLogs(models.Model):
    log_id      = models.AutoField(primary_key=True)
    user        = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, db_column='user_id')
    search_type = models.CharField(max_length=20)
    search_query= models.CharField(max_length=255)
    user_ip     = models.CharField(max_length=45, blank=True, null=True)
    status      = models.CharField(max_length=20, default='pending')
    created_at  = models.DateTimeField(default=timezone.now)
    updated_at  = models.DateTimeField(auto_now=True)

    class Meta:
        managed = True
        db_table = 'user_input_logs'

    def __str__(self):
        return f'Log #{self.log_id} - {self.search_type}'

class EmailSearchResults(models.Model):
    id             = models.AutoField(primary_key=True)
    log            = models.ForeignKey(UsersInputLogs, on_delete=models.CASCADE, db_column='log_id')
    user           = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, db_column='user_id')
    email          = models.CharField(max_length=255)
    is_deliverable = models.BooleanField(default=False)
    is_disposable  = models.BooleanField(default=False)
    breach_count   = models.IntegerField(default=0)
    breach_sources = models.JSONField(blank=True, null=True)
    domain_age_days= models.IntegerField(blank=True, null=True)
    created_at     = models.DateTimeField(default=timezone.now)

    class Meta:
        managed = True
        db_table = 'email_search_results'

    def __str__(self):
        return self.email

class PhoneSearchResults(models.Model):
    id           = models.AutoField(primary_key=True)
    log          = models.ForeignKey(UsersInputLogs, on_delete=models.CASCADE, db_column='log_id')
    user         = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, db_column='user_id')
    phone_number = models.CharField(max_length=20)
    country_code = models.CharField(max_length=5, blank=True, null=True)
    carrier      = models.CharField(max_length=100, blank=True, null=True)
    line_type    = models.CharField(max_length=50, blank=True, null=True)
    spam_score   = models.IntegerField(default=0)
    location     = models.CharField(max_length=255, blank=True, null=True)
    created_at   = models.DateTimeField(default=timezone.now)

    class Meta:
        managed = True
        db_table = 'phone_search_results'

    def __str__(self):
        return self.phone_number

class UsernameSearchResults(models.Model):
    id            = models.AutoField(primary_key=True)
    log           = models.ForeignKey(UsersInputLogs, on_delete=models.CASCADE, db_column='log_id')
    user          = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, db_column='user_id')
    username      = models.CharField(max_length=255)
    platform_name = models.CharField(max_length=100)
    profile_url   = models.CharField(max_length=500, blank=True, null=True)
    is_registered = models.BooleanField(default=False)
    created_at    = models.DateTimeField(default=timezone.now)

    class Meta:
        managed = True
        db_table = 'username_search_results'

    def __str__(self):
        return f'{self.username} on {self.platform_name}'

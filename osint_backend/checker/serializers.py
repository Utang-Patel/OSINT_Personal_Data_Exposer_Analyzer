"""
checker/serializers.py
----------------------
DRF serializers for input validation and model serialization.
"""

from rest_framework import serializers  # type: ignore
from .models import User, ScanRequest, BreachResult, ContinuousMonitoring, Report, Alert, UserFeedback  # type: ignore


# ---------------------------------------------------------------------------
# Legacy input-only serializers (HIBP endpoints)
# ---------------------------------------------------------------------------

class EmailCheckSerializer(serializers.Serializer):
    email = serializers.EmailField()


class PasswordCheckSerializer(serializers.Serializer):
    password = serializers.CharField(min_length=1, max_length=512, trim_whitespace=False)


# ---------------------------------------------------------------------------
# Auth serializers
# ---------------------------------------------------------------------------

class RegisterSerializer(serializers.Serializer):
    email      = serializers.EmailField(max_length=50)
    first_name = serializers.CharField(max_length=10)
    last_name  = serializers.CharField(max_length=10, required=False, allow_blank=True)
    phone      = serializers.CharField(max_length=15, required=False, allow_blank=True)
    password   = serializers.CharField(min_length=8, max_length=128, trim_whitespace=False)


class UpdateProfileSerializer(serializers.Serializer):
    email      = serializers.EmailField()
    first_name = serializers.CharField(max_length=10)
    last_name  = serializers.CharField(max_length=10, required=False, allow_blank=True)


class LoginSerializer(serializers.Serializer):
    email    = serializers.EmailField()
    password = serializers.CharField(min_length=1, trim_whitespace=False)


class DeleteAccountSerializer(serializers.Serializer):
    email    = serializers.EmailField()
    password = serializers.CharField(min_length=1, trim_whitespace=False)


class ForgotPasswordSerializer(serializers.Serializer):
    email = serializers.EmailField()


class ResetPasswordSerializer(serializers.Serializer):
    email        = serializers.EmailField()
    otp          = serializers.CharField(min_length=1, max_length=10)
    new_password = serializers.CharField(min_length=8, max_length=128, trim_whitespace=False)


# ---------------------------------------------------------------------------
# User model serializer
# ---------------------------------------------------------------------------

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model  = User
        fields = [
            'user_id', 'first_name', 'last_name',
            'email', 'phone', 'is_verified', 'created_at',
        ]
        read_only_fields = fields


# ---------------------------------------------------------------------------
# ScanRequest serializers
# ---------------------------------------------------------------------------

class ScanRequestCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model  = ScanRequest
        fields = ['user_id', 'input_type', 'input_value', 'face_path']

    user_id = serializers.IntegerField()

    def create(self, validated_data):
        user_id = validated_data.pop('user_id')
        return ScanRequest.objects.create(user_id=user_id, **validated_data)


class ScanRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model  = ScanRequest
        fields = [
            'input_id', 'user_id', 'input_type', 'input_value',
            'face_path', 'status', 'requested_at', 'updated_at',
        ]


# ---------------------------------------------------------------------------
# BreachResult serializer
# ---------------------------------------------------------------------------

class BreachResultSerializer(serializers.ModelSerializer):
    class Meta:
        model  = BreachResult
        fields = [
            'result_id', 'input_id', 'site_name', 'site_url',
            'risk_level', 'leaked_data', 'detected_at',
        ]


# ---------------------------------------------------------------------------
# ContinuousMonitoring serializers
# ---------------------------------------------------------------------------

class MonitoringCreateSerializer(serializers.ModelSerializer):
    user_id = serializers.IntegerField()

    class Meta:
        model  = ContinuousMonitoring
        fields = ['user_id', 'input_type', 'input_value', 'face_path', 'frequency_minutes']

    def create(self, validated_data):
        user_id = validated_data.pop('user_id')
        return ContinuousMonitoring.objects.create(user_id=user_id, **validated_data)


class MonitoringSerializer(serializers.ModelSerializer):
    class Meta:
        model  = ContinuousMonitoring
        fields = [
            'monitor_id', 'user_id', 'input_type', 'input_value',
            'face_path', 'status', 'frequency_minutes',
            'last_checked_at', 'created_at', 'updated_at',
        ]


# ---------------------------------------------------------------------------
# Report serializer
# ---------------------------------------------------------------------------

class ReportSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Report
        fields = [
            'report_id', 'input_id', 'result_count', 'highest_risk',
            'report_name', 'report_format', 'report_path',
            'summary', 'generated_at', 'viewed_at',
        ]


# ---------------------------------------------------------------------------
# Alert serializers
# ---------------------------------------------------------------------------

class AlertSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Alert
        fields = [
            'alert_id', 'user_id', 'monitor_id', 'result_id',
            'channel', 'message', 'severity', 'status',
            'sent_at', 'read_at',
        ]


# ---------------------------------------------------------------------------
# UserFeedback serializer
# ---------------------------------------------------------------------------

class FeedbackCreateSerializer(serializers.ModelSerializer):
    user_id = serializers.IntegerField()

    class Meta:
        model  = UserFeedback
        fields = ['user_id', 'subject', 'message', 'feedback_type']

    def create(self, validated_data):
        user_id = validated_data.pop('user_id')
        return UserFeedback.objects.create(user_id=user_id, **validated_data)


class FeedbackSerializer(serializers.ModelSerializer):
    class Meta:
        model  = UserFeedback
        fields = [
            'feedback_id', 'user_id', 'subject', 'message',
            'feedback_type', 'status', 'submitted_at', 'resolved_at',
        ]

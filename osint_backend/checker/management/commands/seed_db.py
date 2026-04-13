"""
checker/management/commands/seed_db.py
---------------------------------------
Seeds all 7 OSINT tables with realistic sample data.
Run with:  python manage.py seed_db
Use --clear to wipe before seeding:  python manage.py seed_db --clear
"""

import hashlib
from django.core.management.base import BaseCommand
from django.utils import timezone

from checker.models import (
    User, ScanRequest, BreachResult,
    ContinuousMonitoring, Report, Alert, UserFeedback,
)


def _hash(password: str) -> str:
    """SHA-256 hash — matches the hash used by the API's _hash_password()."""
    return hashlib.sha256(password.encode()).hexdigest()


class Command(BaseCommand):
    help = 'Seed the breach_monitoring database with sample data.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--clear', action='store_true',
            help='Delete existing rows before inserting.',
        )

    def handle(self, *args, **options):

        if options['clear']:
            self.stdout.write('Clearing existing data (in FK order)...')
            UserFeedback.objects.all().delete()
            Alert.objects.all().delete()
            Report.objects.all().delete()
            ContinuousMonitoring.objects.all().delete()
            BreachResult.objects.all().delete()
            ScanRequest.objects.all().delete()
            User.objects.all().delete()
            self.stdout.write(self.style.WARNING('  All rows deleted.'))

        now = timezone.now()

        # ── 1. USERS (10) ────────────────────────────────────────────────────
        self.stdout.write('Seeding users...')
        users_raw = [
            ('Aryan',   'Patel',   'aryan@example.com',   '9876543210', 'Pass@1234'),
            ('Priya',   'Sharma',  'priya@example.com',   '9123456780', 'Priya@5678'),
            ('Rohan',   'Mehta',   'rohan@example.com',   '9234567891', 'Rohan@2024'),
            ('Sneha',   'Gupta',   'sneha@example.com',   '9345678902', 'Sneha@9876'),
            ('Karan',   'Singh',   'karan@example.com',   '9456789013', 'Karan@1111'),
            ('Neha',    'Joshi',   'neha@example.com',    '9567890124', 'Neha@2222'),
            ('Amit',    'Kumar',   'amit@example.com',    '9678901235', 'Amit@3333'),
            ('Pooja',   'Verma',   'pooja@example.com',   '9789012346', 'Pooja@4444'),
            ('Vikram',  'Rao',     'vikram@example.com',  '9890123457', 'Vikram@55'),
            ('Deepa',   'Nair',    'deepa@example.com',   '9901234568', 'Deepa@666'),
        ]
        users = []
        for fn, ln, email, phone, pwd in users_raw:
            u, _ = User.objects.get_or_create(
                email=email,
                defaults=dict(
                    first_name=fn, last_name=ln, phone=phone,
                    password=_hash(pwd),
                    is_superuser=0, is_staff=0, is_active=1,
                    is_otp_verified=1,
                    date_joined=now, created_at=now,
                )
            )
            users.append(u)
        self.stdout.write(self.style.SUCCESS(f'  {len(users)} users ready.'))

        # ── 2. SCAN REQUESTS (9) ─────────────────────────────────────────────
        self.stdout.write('Seeding scan_requests...')
        scans_raw = [
            (users[0], 'email', 'aryan@example.com',   None,             'completed'),
            (users[1], 'email', 'priya@example.com',   None,             'completed'),
            (users[2], 'phone', '9234567891',          None,             'completed'),
            (users[3], 'email', 'sneha@example.com',   None,             'running'),
            (users[4], 'phone', '9456789013',          None,             'completed'),
            (users[5], 'email', 'neha@example.com',    None,             'completed'),
            (users[6], 'face',  None,                  '/faces/amit.jpg','completed'),
            (users[7], 'email', 'pooja@example.com',   None,             'completed'),
            (users[8], 'phone', '9890123457',          None,             'pending'),
        ]
        scans = []
        for user, itype, ival, fpath, stat in scans_raw:
            s, _ = ScanRequest.objects.get_or_create(
                user=user, input_type=itype, input_value=ival,
                defaults=dict(face_path=fpath, status=stat, created_at=now)
            )
            scans.append(s)
        self.stdout.write(self.style.SUCCESS(f'  {len(scans)} scan requests ready.'))

        # ── 3. BREACH RESULTS (8) ────────────────────────────────────────────
        self.stdout.write('Seeding breach_results...')
        breaches_raw = [
            (scans[0], 'LinkedIn',   85, 'high',     ['Email', 'Password', 'Name']),
            (scans[0], 'Adobe',      55, 'medium',   ['Email', 'Password']),
            (scans[1], 'Canva',      30, 'low',      ['Email', 'Username']),
            (scans[1], 'Dropbox',    90, 'critical', ['Email', 'Password hash', 'IP Address']),
            (scans[2], 'Truecaller', 60, 'medium',   ['Phone', 'Name']),
            (scans[4], 'JustDial',   25, 'low',      ['Phone', 'Address']),
            (scans[5], 'Zomato',     65, 'medium',   ['Email', 'Phone', 'Name']),
            (scans[6], 'Facebook',   95, 'critical', ['Face', 'Name', 'Location']),
        ]
        bresults = []
        for scan, bname, score, sev, leaked in breaches_raw:
            br, _ = BreachResult.objects.get_or_create(
                scan_request=scan, breach_name=bname,
                defaults=dict(risk_score=score, severity=sev, leaked_data=leaked, found_at=now)
            )
            bresults.append(br)
        self.stdout.write(self.style.SUCCESS(f'  {len(bresults)} breach results ready.'))

        # ── 4. CONTINUOUS MONITORING (8) ─────────────────────────────────────
        self.stdout.write('Seeding continuous_monitoring...')
        monitors_raw = [
            (users[0], 'email', 'aryan@example.com',  1, 60),
            (users[1], 'email', 'priya@example.com',  1, 30),
            (users[2], 'phone', '9234567891',         0, 120),
            (users[3], 'email', 'sneha@example.com',  1, 60),
            (users[4], 'phone', '9456789013',         1, 240),
            (users[5], 'email', 'neha@example.com',   0, 60),
            (users[6], 'face',  'amit_face',          1, 1440),
            (users[7], 'email', 'pooja@example.com',  1, 60),
        ]
        monitors = []
        for user, ttype, tval, active, freq in monitors_raw:
            m, _ = ContinuousMonitoring.objects.get_or_create(
                user=user, target_type=ttype, target_value=tval,
                defaults=dict(is_active=active, frequency_minutes=freq, last_checked_at=now)
            )
            monitors.append(m)
        self.stdout.write(self.style.SUCCESS(f'  {len(monitors)} monitoring entries ready.'))

        # ── 5. REPORTS (8) ───────────────────────────────────────────────────
        self.stdout.write('Seeding reports...')
        reports_raw = [
            (users[0], 'Found 2 breaches: LinkedIn (high) and Adobe (medium). Immediate password change recommended.',    'pdf',  '/reports/aryan.pdf'),
            (users[1], 'Found 2 breaches: Dropbox (critical) and Canva (low). Critical action required.',                'pdf',  '/reports/priya.pdf'),
            (users[2], 'Phone number found in Truecaller breach. Medium risk exposure detected.',                         'html', '/reports/rohan.html'),
            (users[4], 'Phone found in JustDial data exposure. Low risk — no passwords leaked.',                          'pdf',  '/reports/karan.pdf'),
            (users[5], 'Email found in Zomato breach (2022). Medium risk — change password on Zomato.',                  'json', '/reports/neha.json'),
            (users[6], 'Face biometric matched in Facebook database. Critical risk — review privacy settings.',           'pdf',  '/reports/amit.pdf'),
            (users[7], 'No active breaches found for this email. Keep monitoring enabled.',                               'pdf',  '/reports/pooja.pdf'),
            (users[3], 'Scan still in progress — no results yet. Report will be updated when complete.',                  'pdf',  '/reports/sneha.pdf'),
        ]
        rpts = []
        for user, summary, fmt, path in reports_raw:
            r, _ = Report.objects.get_or_create(
                user=user, report_path=path,
                defaults=dict(summary=summary, report_format=fmt, created_at=now)
            )
            rpts.append(r)
        self.stdout.write(self.style.SUCCESS(f'  {len(rpts)} reports ready.'))

        # ── 6. ALERTS (5) ────────────────────────────────────────────────────
        self.stdout.write('Seeding alerts...')
        alerts_raw = [
            (users[0], bresults[0], 'in_app', '🚨 Your email was found in the LinkedIn breach! Immediate action required.', 0),
            (users[1], bresults[3], 'email',  '⚠️ Critical: Dropbox breach detected — your password hash was exposed.',     1),
            (users[2], bresults[4], 'in_app', '📱 Your phone number appeared in a Truecaller data leak.',                   0),
            (users[5], bresults[6], 'in_app', '📧 Your email was detected in the Zomato data breach from 2022.',            0),
            (users[6], bresults[7], 'email',  '🔴 Face biometric matched in Facebook database. Review your account now.',   0),
        ]
        alts = []
        for user, breach, channel, msg, is_read in alerts_raw:
            a, _ = Alert.objects.get_or_create(
                user=user, breach_result=breach,
                defaults=dict(channel=channel, message=msg, is_read=is_read, created_at=now)
            )
            alts.append(a)
        self.stdout.write(self.style.SUCCESS(f'  {len(alts)} alerts ready.'))

        # ── 7. USER FEEDBACK (1) ─────────────────────────────────────────────
        self.stdout.write('Seeding user_feedback...')
        fb, _ = UserFeedback.objects.get_or_create(
            user=users[0],
            defaults=dict(
                category='Feature Request',
                message=(
                    'The application works really well for tracking data exposure! '
                    'Would love to see a dark mode and push notifications for new breaches. '
                    'Also, a weekly summary email would be very helpful.'
                ),
                status='new',
                created_at=now,
            )
        )
        self.stdout.write(self.style.SUCCESS('  1 feedback entry ready.'))

        # ── Summary ───────────────────────────────────────────────────────────
        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS('=' * 55))
        self.stdout.write(self.style.SUCCESS('✅  Database seeded successfully!'))
        self.stdout.write(self.style.SUCCESS(f'  Users:               {User.objects.count():>3}'))
        self.stdout.write(self.style.SUCCESS(f'  Scan Requests:       {ScanRequest.objects.count():>3}'))
        self.stdout.write(self.style.SUCCESS(f'  Breach Results:      {BreachResult.objects.count():>3}'))
        self.stdout.write(self.style.SUCCESS(f'  Monitoring Entries:  {ContinuousMonitoring.objects.count():>3}'))
        self.stdout.write(self.style.SUCCESS(f'  Reports:             {Report.objects.count():>3}'))
        self.stdout.write(self.style.SUCCESS(f'  Alerts:              {Alert.objects.count():>3}'))
        self.stdout.write(self.style.SUCCESS(f'  Feedback:            {UserFeedback.objects.count():>3}'))
        self.stdout.write(self.style.SUCCESS('=' * 55))

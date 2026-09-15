import 'dart:io';

import 'package:flutter/foundation.dart';

import '../local/hsabat_local_store.dart';

/// يسجّل مهمة Windows Scheduler لرفع باك أب يومي حتى لو التطبيق مغلق.
class WindowsDailyBackupScheduler {
  static const taskName = 'HsabatPlansDailyBackup';

  final HsabatLocalStore _store;

  WindowsDailyBackupScheduler(this._store);

  bool get isSupported => !kIsWeb && Platform.isWindows;

  Future<String> ensureScriptInstalled() async {
    final script = await _store.backupScriptFile();
    await script.writeAsString(_powershellScript, flush: true);
    return script.path;
  }

  /// يسجّل/يحدّث مهمة يومية الساعة 02:00.
  Future<void> enableDailyTask({String time = '02:00'}) async {
    if (!isSupported) {
      throw Exception('المهمة التلقائية متاحة على Windows فقط.');
    }

    final scriptPath = await ensureScriptInstalled();
    final configPath = (await _store.backupConfigFile()).path;
    final lastBackupPath = (await _store.lastBackupFile()).path;

    final tr =
        'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$scriptPath" -ConfigPath "$configPath" -LastBackupPath "$lastBackupPath"';

    final result = await Process.run(
      'schtasks',
      [
        '/Create',
        '/TN',
        taskName,
        '/SC',
        'DAILY',
        '/ST',
        time,
        '/RL',
        'LIMITED',
        '/F',
        '/TR',
        tr,
      ],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      final err = '${result.stderr}\n${result.stdout}'.trim();
      throw Exception(
        err.isEmpty ? 'فشل تسجيل المهمة التلقائية (schtasks).' : err,
      );
    }
  }

  Future<void> disableDailyTask() async {
    if (!isSupported) {
      return;
    }
    await Process.run(
      'schtasks',
      ['/Delete', '/TN', taskName, '/F'],
      runInShell: true,
    );
  }

  Future<bool> isDailyTaskRegistered() async {
    if (!isSupported) {
      return false;
    }
    final result = await Process.run(
      'schtasks',
      ['/Query', '/TN', taskName],
      runInShell: true,
    );
    return result.exitCode == 0;
  }

  static const _powershellScript = r'''
param(
  [Parameter(Mandatory = $true)][string]$ConfigPath,
  [Parameter(Mandatory = $true)][string]$LastBackupPath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  throw "ملف إعدادات النسخ غير موجود: $ConfigPath"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$baseUrl = ([string]$config.baseUrl).Trim().TrimEnd("/")
$apiKey = ([string]$config.apiKey).Trim()
$plansPath = [string]$config.plansPath
$doctorSelectionPath = [string]$config.doctorSelectionPath

if ([string]::IsNullOrWhiteSpace($baseUrl) -or [string]::IsNullOrWhiteSpace($apiKey)) {
  throw "baseUrl أو apiKey فارغ في backup_config.json"
}
if (-not (Test-Path -LiteralPath $plansPath)) {
  throw "ملف الخطط غير موجود: $plansPath"
}

$plansRaw = Get-Content -LiteralPath $plansPath -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($plansRaw)) {
  $plansRaw = "[]"
}

$plansJson = $plansRaw | ConvertFrom-Json
$doctorSelectionObject = @{
  selectedDoctors = @()
  ownerDoctor = $null
  totalTamweel = 0
}
if (-not [string]::IsNullOrWhiteSpace($doctorSelectionPath) -and (Test-Path -LiteralPath $doctorSelectionPath)) {
  $doctorSelectionRaw = Get-Content -LiteralPath $doctorSelectionPath -Raw -Encoding UTF8
  if (-not [string]::IsNullOrWhiteSpace($doctorSelectionRaw)) {
    $doctorSelectionObject = $doctorSelectionRaw | ConvertFrom-Json
  }
}

$bodyObject = @{
  schemaVersion = 1
  plans = @($plansJson)
  doctorSelection = $doctorSelectionObject
}
$body = $bodyObject | ConvertTo-Json -Depth 40 -Compress
$bytes = [System.Text.Encoding]::UTF8.GetBytes($body)

$uri = "$baseUrl/api/backup/app-state"
$headers = @{ "x-api-key" = $apiKey; "Accept" = "application/json" }

try {
  Invoke-RestMethod -Method Put -Uri $uri -Headers $headers -ContentType "application/json; charset=utf-8" -Body $bytes | Out-Null
} catch {
  # fallback للتوافق مع backend القديمة (plans only).
  $fallbackBody = @{ plans = @($plansJson) } | ConvertTo-Json -Depth 30 -Compress
  $fallbackBytes = [System.Text.Encoding]::UTF8.GetBytes($fallbackBody)
  $fallbackUri = "$baseUrl/api/backup/plans"
  Invoke-RestMethod -Method Put -Uri $fallbackUri -Headers $headers -ContentType "application/json; charset=utf-8" -Body $fallbackBytes | Out-Null
}

$stamp = [DateTime]::UtcNow.ToString("o")
Set-Content -LiteralPath $LastBackupPath -Value $stamp -Encoding UTF8
Write-Output "OK backup at $stamp"
''';
}

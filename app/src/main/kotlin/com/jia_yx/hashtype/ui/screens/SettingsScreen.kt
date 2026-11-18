package com.jia_yx.hashtype.ui.screens

import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jia_yx.hashtype.HashtypeFloatingService
import com.jia_yx.hashtype.data.AiProviders
import com.jia_yx.hashtype.data.AppSettings

@Composable
fun SettingsScreen() {
    val context = LocalContext.current

    var floatingMicEnabled by remember { mutableStateOf(AppSettings.isFloatingMicEnabled(context)) }
    var languageSummary by remember { mutableStateOf(AppSettings.getSelectedLanguageNames(context)) }
    var sttConfig by remember { mutableStateOf(AiProviders.getSttConfig(context)) }
    var llmConfig by remember { mutableStateOf(AiProviders.getLlmConfig(context)) }
    var isAccessibilityEnabled by remember { mutableStateOf(checkAccessibilityServiceEnabled(context)) }

    var showLanguageDialog by remember { mutableStateOf(false) }
    var showCustomizeDialog by remember { mutableStateOf(false) }
    var showSttDialog by remember { mutableStateOf(false) }
    var showLlmDialog by remember { mutableStateOf(false) }
    var showAboutDialog by remember { mutableStateOf(false) }

    fun refresh() {
        floatingMicEnabled = AppSettings.isFloatingMicEnabled(context)
        languageSummary = AppSettings.getSelectedLanguageNames(context)
        sttConfig = AiProviders.getSttConfig(context)
        llmConfig = AiProviders.getLlmConfig(context)
        isAccessibilityEnabled = checkAccessibilityServiceEnabled(context)
    }

    LaunchedEffect(Unit) {
        refresh()
    }

    if (showLanguageDialog) {
        LanguageSelectionDialog(
            onDismiss = {
                showLanguageDialog = false
                refresh()
            }
        )
    }

    if (showCustomizeDialog) {
        FloatingMicCustomizeDialog(
            onDismiss = {
                showCustomizeDialog = false
                refresh()
            }
        )
    }

    if (showSttDialog) {
        SttSettingsDialog(
            onDismiss = {
                showSttDialog = false
                refresh()
            }
        )
    }

    if (showLlmDialog) {
        LlmSettingsDialog(
            onDismiss = {
                showLlmDialog = false
                refresh()
            }
        )
    }

    if (showAboutDialog) {
        AlertDialog(
            onDismissRequest = { showAboutDialog = false },
            icon = { Icon(Icons.Default.Info, contentDescription = null) },
            title = { Text("About Hashtype") },
            text = {
                Column {
                    Text("Hashtype Voice Input & Assistant", fontWeight = FontWeight.Bold)
                    Text("Version 2.0.0 (Native Kotlin)")
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("Lightweight speech-to-text input method and cursor-driven floating microphone.")
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("License: GNU General Public License v3.0", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.outline)
                }
            },
            confirmButton = {
                TextButton(onClick = { showAboutDialog = false }) {
                    Text("OK")
                }
            }
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
    ) {
        // Floating Voice Input Section
        SectionHeader("Floating Voice Input")

        SettingCard(
            icon = Icons.Default.BubbleChart,
            title = "Enable Floating Mic",
            subtitle = "Show mic button when text cursor is active",
            trailing = {
                Switch(
                    checked = floatingMicEnabled,
                    onCheckedChange = { checked ->
                        floatingMicEnabled = checked
                        AppSettings.setFloatingMicEnabled(context, checked)
                        HashtypeFloatingService.updateSettings()
                    }
                )
            }
        )

        SettingCard(
            icon = Icons.Default.AccessibilityNew,
            title = "Auto-Paste Helper",
            subtitle = if (isAccessibilityEnabled) "Accessibility Service active" else "Tap to enable auto-paste",
            subtitleColor = if (isAccessibilityEnabled) null else MaterialTheme.colorScheme.error,
            trailing = {
                Icon(
                    imageVector = if (isAccessibilityEnabled) Icons.Default.CheckCircle else Icons.Default.Warning,
                    contentDescription = null,
                    tint = if (isAccessibilityEnabled) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error
                )
            },
            onClick = {
                val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
            }
        )

        SettingCard(
            icon = Icons.Default.Tune,
            title = "Customize Floating Mic",
            subtitle = "Button size, dynamic colors, and icons",
            onClick = { showCustomizeDialog = true }
        )

        Spacer(modifier = Modifier.height(20.dp))

        // Voice & Language Section
        SectionHeader("Voice & Language")

        SettingCard(
            icon = Icons.Default.Language,
            title = "Input Language",
            subtitle = languageSummary,
            onClick = { showLanguageDialog = true }
        )

        Spacer(modifier = Modifier.height(20.dp))

        // AI Models Section
        SectionHeader("AI Models")

        val sttSubtitle = if (sttConfig.apiKey.isBlank()) {
            "Tap to configure API key & model"
        } else {
            "${sttConfig.provider} (${sttConfig.model})"
        }
        val sttNeedsConfig = sttConfig.apiKey.isBlank()

        SettingCard(
            icon = Icons.Default.Mic,
            title = "Speech-to-Text",
            subtitle = sttSubtitle,
            subtitleColor = if (sttNeedsConfig) MaterialTheme.colorScheme.error else null,
            onClick = { showSttDialog = true }
        )

        val llmSubtitle = if (!llmConfig.enabled) {
            "Disabled"
        } else if (llmConfig.apiKey.isBlank()) {
            "Tap to configure API key & model"
        } else {
            "${llmConfig.provider} (${llmConfig.model})"
        }

        SettingCard(
            icon = Icons.Default.Psychology,
            title = "Language Models",
            subtitle = llmSubtitle,
            trailing = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = if (llmConfig.enabled) "On" else "Off",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.outline
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Icon(
                        imageVector = Icons.Default.ChevronRight,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.outline
                    )
                }
            },
            onClick = { showLlmDialog = true }
        )

        Spacer(modifier = Modifier.height(20.dp))

        // System Section
        SectionHeader("System")

        SettingCard(
            icon = Icons.Default.Info,
            title = "About",
            subtitle = "Version 2.0.0 (Native Kotlin)",
            onClick = { showAboutDialog = true }
        )
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title.uppercase(),
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.Bold,
        color = MaterialTheme.colorScheme.primary,
        letterSpacing = 1.2.sp,
        modifier = Modifier.padding(start = 8.dp, bottom = 8.dp)
    )
}

@Composable
private fun SettingCard(
    icon: ImageVector,
    title: String,
    subtitle: String,
    subtitleColor: androidx.compose.ui.graphics.Color? = null,
    trailing: @Composable (() -> Unit)? = null,
    onClick: (() -> Unit)? = null
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)
        ),
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(24.dp)
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = subtitleColor ?: MaterialTheme.colorScheme.outline
                )
            }
            if (trailing != null) {
                Spacer(modifier = Modifier.width(8.dp))
                trailing()
            } else if (onClick != null) {
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.outline
                )
            }
        }
    }
}

private fun checkAccessibilityServiceEnabled(context: Context): Boolean {
    val expected = "${context.packageName}/${HashtypeFloatingService::class.java.canonicalName}"
    val settingValue = Settings.Secure.getString(
        context.contentResolver,
        Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
    )
    return settingValue?.contains(expected) == true
}

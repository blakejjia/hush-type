package com.jia_yx.hashtype.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.jia_yx.hashtype.HashtypeFloatingService
import com.jia_yx.hashtype.data.AppSettings

data class ColorPreset(val name: String, val hex: String, val color: Color)

val COLOR_PRESETS = listOf(
    ColorPreset("Indigo", "#FF6366F1", Color(0xFF6366F1)),
    ColorPreset("Sky Blue", "#FF0EA5E9", Color(0xFF0EA5E9)),
    ColorPreset("Emerald", "#FF10B981", Color(0xFF10B981)),
    ColorPreset("Amber", "#FFF59E0B", Color(0xFFF59E0B)),
    ColorPreset("Red", "#FFEF4444", Color(0xFFEF4444)),
    ColorPreset("Fuchsia", "#FFD946EF", Color(0xFFD946EF)),
    ColorPreset("Violet", "#FF8B5CF6", Color(0xFF8B5CF6)),
    ColorPreset("Slate", "#FF64748B", Color(0xFF64748B)),
    ColorPreset("Rose", "#FFF43F5E", Color(0xFFF43F5E)),
    ColorPreset("Lime", "#FF84CC16", Color(0xFF84CC16))
)

val ICON_OPTIONS = listOf(
    "mic" to Icons.Default.Mic,
    "heart" to Icons.Default.Favorite,
    "star" to Icons.Default.Star,
    "chat" to Icons.Default.ChatBubble,
    "music" to Icons.Default.MusicNote
)

@Composable
fun FloatingMicCustomizeDialog(
    onDismiss: () -> Unit
) {
    val context = LocalContext.current

    var selectedSize by remember { mutableStateOf(AppSettings.getFloatingMicSize(context)) }
    var selectedColor by remember { mutableStateOf(AppSettings.getFloatingMicColor(context)) }
    var selectedIcon by remember { mutableStateOf(AppSettings.getFloatingMicIcon(context)) }
    var isMockRecording by remember { mutableStateOf(false) }

    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1.0f,
        targetValue = if (isMockRecording) 1.15f else 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "scale"
    )

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth(0.95f)
                .fillMaxHeight(0.9f),
            shape = RoundedCornerShape(28.dp),
            color = MaterialTheme.colorScheme.surface
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(24.dp)
            ) {
                Text(
                    text = "Customize Floating Mic",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )

                Spacer(modifier = Modifier.height(16.dp))

                Column(
                    modifier = Modifier
                        .weight(1f)
                        .verticalScroll(rememberScrollState())
                ) {
                    // Live Preview Area
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(160.dp),
                        shape = RoundedCornerShape(20.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                        )
                    ) {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            val buttonSizeDp = when (selectedSize) {
                                "small" -> 44.dp
                                "large" -> 68.dp
                                else -> 56.dp
                            }
                            val iconSizeDp = when (selectedSize) {
                                "small" -> 20.dp
                                "large" -> 28.dp
                                else -> 24.dp
                            }

                            val previewBg = if (isMockRecording) {
                                MaterialTheme.colorScheme.errorContainer
                            } else if (selectedColor == "theme") {
                                MaterialTheme.colorScheme.secondaryContainer
                            } else {
                                try {
                                    Color(android.graphics.Color.parseColor(selectedColor))
                                } catch (_: Exception) {
                                    MaterialTheme.colorScheme.secondaryContainer
                                }
                            }

                            val previewIconColor = if (isMockRecording) {
                                MaterialTheme.colorScheme.onErrorContainer
                            } else if (selectedColor == "theme") {
                                MaterialTheme.colorScheme.onSecondaryContainer
                            } else {
                                Color.White
                            }

                            val iconVector = ICON_OPTIONS.find { it.first == selectedIcon }?.second ?: Icons.Default.Mic

                            Box(
                                modifier = Modifier
                                    .scale(if (isMockRecording) pulseScale else 1.0f)
                                    .size(buttonSizeDp)
                                    .background(previewBg, CircleShape)
                                    .clickable { isMockRecording = !isMockRecording },
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = iconVector,
                                    contentDescription = null,
                                    tint = previewIconColor,
                                    modifier = Modifier.size(iconSizeDp)
                                )
                            }

                            Text(
                                text = if (isMockRecording) "Recording state (tap to toggle)" else "Idle state (tap to test pulse)",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.outline,
                                modifier = Modifier
                                    .align(Alignment.BottomCenter)
                                    .padding(bottom = 8.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(24.dp))

                    // Size Selection
                    Text(
                        text = "Button Size",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        listOf("small" to "Small (44dp)", "medium" to "Medium (56dp)", "large" to "Large (68dp)").forEach { (key, label) ->
                            FilterChip(
                                selected = selectedSize == key,
                                onClick = { selectedSize = key },
                                label = { Text(label, fontSize = 12.sp) },
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(24.dp))

                    // Icon Selection
                    Text(
                        text = "Button Icon",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        ICON_OPTIONS.forEach { (key, icon) ->
                            val isSelected = selectedIcon == key
                            Surface(
                                shape = RoundedCornerShape(14.dp),
                                color = if (isSelected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
                                modifier = Modifier
                                    .size(52.dp)
                                    .clickable { selectedIcon = key }
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Icon(
                                        imageVector = icon,
                                        contentDescription = key,
                                        tint = if (isSelected) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(24.dp))

                    // Color Selection
                    Text(
                        text = "Button Color",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    Spacer(modifier = Modifier.height(8.dp))

                    Card(
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)
                        )
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text("Use System Dynamic Colors", fontWeight = FontWeight.Medium)
                                    Text(
                                        "Adapts to phone wallpaper theme",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.outline
                                    )
                                }
                                Switch(
                                    checked = selectedColor == "theme",
                                    onCheckedChange = { useTheme ->
                                        selectedColor = if (useTheme) "theme" else COLOR_PRESETS.first().hex
                                    }
                                )
                            }

                            if (selectedColor != "theme") {
                                Spacer(modifier = Modifier.height(12.dp))
                                Text(
                                    "Presets",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.outline
                                )
                                Spacer(modifier = Modifier.height(8.dp))

                                LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    items(COLOR_PRESETS) { preset ->
                                        val isSelected = selectedColor == preset.hex
                                        Box(
                                            modifier = Modifier
                                                .size(42.dp)
                                                .background(preset.color, CircleShape)
                                                .border(
                                                    width = if (isSelected) 3.dp else 0.dp,
                                                    color = if (isSelected) MaterialTheme.colorScheme.onSurface else Color.Transparent,
                                                    shape = CircleShape
                                                )
                                                .clickable { selectedColor = preset.hex },
                                            contentAlignment = Alignment.Center
                                        ) {
                                            if (isSelected) {
                                                Icon(
                                                    imageVector = Icons.Default.Check,
                                                    contentDescription = null,
                                                    tint = Color.White,
                                                    modifier = Modifier.size(20.dp)
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(onClick = onDismiss) {
                        Text("Cancel")
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(
                        onClick = {
                            AppSettings.setFloatingMicSize(context, selectedSize)
                            AppSettings.setFloatingMicColor(context, selectedColor)
                            AppSettings.setFloatingMicIcon(context, selectedIcon)
                            HashtypeFloatingService.updateSettings()
                            onDismiss()
                        }
                    ) {
                        Text("Save & Apply")
                    }
                }
            }
        }
    }
}

package com.jia_yx.hashtype.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.jia_yx.hashtype.HashtypeFloatingService
import com.jia_yx.hashtype.data.AppSettings

private val ICON_OPTIONS = listOf(
    "mic" to Icons.Default.Mic,
    "heart" to Icons.Default.Favorite,
    "star" to Icons.Default.Star,
    "chat" to Icons.Default.ChatBubble,
    "music" to Icons.Default.MusicNote
)

private val SIZE_OPTIONS = listOf(
    "small" to "Small (44dp)",
    "medium" to "Medium (56dp)",
    "large" to "Large (68dp)"
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FloatingMicCustomizeBottomSheet(
    onDismissRequest: () -> Unit
) {
    val context = LocalContext.current
    var selectedSize by remember { mutableStateOf(AppSettings.getFloatingMicSize(context)) }
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

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismissRequest,
        sheetState = sheetState,
        dragHandle = { BottomSheetDefaults.DragHandle() }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp)
                .verticalScroll(rememberScrollState())
        ) {
            Text(
                text = "Customize Floating Mic",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Styling and sizing for cursor-driven voice button",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.outline
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Live Preview Card
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(150.dp),
                shape = RoundedCornerShape(20.dp),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
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
                    } else {
                        MaterialTheme.colorScheme.secondaryContainer
                    }

                    val previewIconColor = if (isMockRecording) {
                        MaterialTheme.colorScheme.onErrorContainer
                    } else {
                        MaterialTheme.colorScheme.onSecondaryContainer
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
                        text = if (isMockRecording) "Recording state (tap to toggle)" else "Dynamic Material You theme (tap to test pulse)",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.outline,
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(bottom = 8.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Size Selector
            Text(
                text = "Button Size",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                SIZE_OPTIONS.forEach { (sizeKey, label) ->
                    val isSelected = selectedSize == sizeKey
                    FilterChip(
                        selected = isSelected,
                        onClick = { selectedSize = sizeKey },
                        label = { Text(label) },
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Icon Selector
            Text(
                text = "Button Icon",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                ICON_OPTIONS.forEach { (iconKey, vector) ->
                    val isSelected = selectedIcon == iconKey
                    OutlinedCard(
                        shape = RoundedCornerShape(14.dp),
                        colors = CardDefaults.outlinedCardColors(
                            containerColor = if (isSelected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface
                        ),
                        border = if (isSelected) {
                            CardDefaults.outlinedCardBorder().copy(brush = androidx.compose.ui.graphics.SolidColor(MaterialTheme.colorScheme.primary))
                        } else {
                            CardDefaults.outlinedCardBorder()
                        },
                        modifier = Modifier
                            .weight(1f)
                            .clickable { selectedIcon = iconKey }
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 12.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = vector,
                                contentDescription = iconKey,
                                tint = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(28.dp))

            // Buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                TextButton(onClick = onDismissRequest) {
                    Text("Cancel")
                }
                Spacer(modifier = Modifier.width(8.dp))
                Button(
                    onClick = {
                        AppSettings.setFloatingMicSize(context, selectedSize)
                        AppSettings.setFloatingMicIcon(context, selectedIcon)
                        AppSettings.setFloatingMicColor(context, "theme")
                        HashtypeFloatingService.updateSettings()
                        onDismissRequest()
                    }
                ) {
                    Text("Save")
                }
            }
        }
    }
}

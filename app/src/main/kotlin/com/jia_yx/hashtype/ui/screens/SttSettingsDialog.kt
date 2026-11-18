package com.jia_yx.hashtype.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.OpenInNew
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.jia_yx.hashtype.data.AiProviders
import com.jia_yx.hashtype.data.SttState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SttSettingsDialog(
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val currentConfig = remember { AiProviders.getSttConfig(context) }

    var selectedProviderName by remember { mutableStateOf(currentConfig.provider) }
    var apiKey by remember { mutableStateOf(currentConfig.apiKey) }
    var selectedModel by remember { mutableStateOf(currentConfig.model) }
    var customEndpoint by remember { mutableStateOf(currentConfig.endpoint) }

    var showPassword by remember { mutableStateOf(false) }
    var providerDropdownExpanded by remember { mutableStateOf(false) }
    var modelDropdownExpanded by remember { mutableStateOf(false) }

    val providerInfo = remember(selectedProviderName) {
        AiProviders.STT_PROVIDERS.find { it.name == selectedProviderName }
            ?: AiProviders.STT_PROVIDERS.first()
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth(0.95f)
                .fillMaxHeight(0.85f),
            shape = RoundedCornerShape(24.dp),
            color = MaterialTheme.colorScheme.surface
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(24.dp)
            ) {
                Text(
                    text = "Speech-to-Text Settings",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )

                Spacer(modifier = Modifier.height(16.dp))

                Column(
                    modifier = Modifier
                        .weight(1f)
                        .verticalScroll(rememberScrollState())
                ) {
                    // Provider Dropdown
                    Text("Provider", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.height(6.dp))
                    ExposedDropdownMenuBox(
                        expanded = providerDropdownExpanded,
                        onExpandedChange = { providerDropdownExpanded = !providerDropdownExpanded }
                    ) {
                        OutlinedTextField(
                            value = selectedProviderName,
                            onValueChange = {},
                            readOnly = true,
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = providerDropdownExpanded) },
                            modifier = Modifier
                                .fillMaxWidth()
                                .menuAnchor(),
                            shape = RoundedCornerShape(14.dp)
                        )
                        ExposedDropdownMenu(
                            expanded = providerDropdownExpanded,
                            onDismissRequest = { providerDropdownExpanded = false }
                        ) {
                            AiProviders.STT_PROVIDERS.forEach { p ->
                                DropdownMenuItem(
                                    text = { Text(p.name) },
                                    onClick = {
                                        selectedProviderName = p.name
                                        selectedModel = p.defaultModels.firstOrNull() ?: ""
                                        providerDropdownExpanded = false
                                    }
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    // API Key Field
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("API Key", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                        if (providerInfo.helpUrl.isNotBlank()) {
                            TextButton(
                                onClick = {
                                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(providerInfo.helpUrl))
                                    context.startActivity(intent)
                                },
                                contentPadding = PaddingValues(0.dp)
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text("Get Key", style = MaterialTheme.typography.labelSmall)
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Icon(Icons.Default.OpenInNew, contentDescription = null, modifier = Modifier.size(12.dp))
                                }
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(6.dp))
                    OutlinedTextField(
                        value = apiKey,
                        onValueChange = { apiKey = it },
                        modifier = Modifier.fillMaxWidth(),
                        placeholder = { Text(providerInfo.apiKeyPlaceholder) },
                        visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                        trailingIcon = {
                            IconButton(onClick = { showPassword = !showPassword }) {
                                Icon(
                                    imageVector = if (showPassword) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                    contentDescription = null
                                )
                            }
                        },
                        shape = RoundedCornerShape(14.dp),
                        singleLine = true
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    // Model Selection
                    Text("Model", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.height(6.dp))
                    if (providerInfo.name == "Custom") {
                        OutlinedTextField(
                            value = selectedModel,
                            onValueChange = { selectedModel = it },
                            modifier = Modifier.fillMaxWidth(),
                            placeholder = { Text("e.g. whisper-1") },
                            shape = RoundedCornerShape(14.dp),
                            singleLine = true
                        )
                    } else {
                        ExposedDropdownMenuBox(
                            expanded = modelDropdownExpanded,
                            onExpandedChange = { modelDropdownExpanded = !modelDropdownExpanded }
                        ) {
                            OutlinedTextField(
                                value = selectedModel,
                                onValueChange = {},
                                readOnly = true,
                                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = modelDropdownExpanded) },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .menuAnchor(),
                                shape = RoundedCornerShape(14.dp)
                            )
                            ExposedDropdownMenu(
                                expanded = modelDropdownExpanded,
                                onDismissRequest = { modelDropdownExpanded = false }
                            ) {
                                providerInfo.defaultModels.forEach { m ->
                                    DropdownMenuItem(
                                        text = { Text(m) },
                                        onClick = {
                                            selectedModel = m
                                            modelDropdownExpanded = false
                                        }
                                    )
                                }
                            }
                        }
                    }

                    if (providerInfo.name == "Custom") {
                        Spacer(modifier = Modifier.height(16.dp))
                        Text("Custom Base URL", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
                        Spacer(modifier = Modifier.height(6.dp))
                        OutlinedTextField(
                            value = customEndpoint,
                            onValueChange = { customEndpoint = it },
                            modifier = Modifier.fillMaxWidth(),
                            placeholder = { Text("https://your-server.com/v1") },
                            shape = RoundedCornerShape(14.dp),
                            singleLine = true
                        )
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
                            val state = SttState(
                                provider = selectedProviderName,
                                apiKey = apiKey.trim(),
                                endpoint = customEndpoint.trim(),
                                model = selectedModel.trim()
                            )
                            AiProviders.saveSttConfig(context, state)
                            onDismiss()
                        }
                    ) {
                        Text("Save")
                    }
                }
            }
        }
    }
}

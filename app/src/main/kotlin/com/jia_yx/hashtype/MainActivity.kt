package com.jia_yx.hashtype

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.jia_yx.hashtype.ui.MainScreen
import com.jia_yx.hashtype.ui.theme.HashtypeTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            HashtypeTheme {
                MainScreen()
            }
        }
    }
}

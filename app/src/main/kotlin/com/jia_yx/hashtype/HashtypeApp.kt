package com.jia_yx.hashtype

import android.app.Application
import com.google.android.material.color.DynamicColors

class HashtypeApp : Application() {
    override fun onCreate() {
        super.onCreate()
        DynamicColors.applyToActivitiesIfAvailable(this)
    }
}

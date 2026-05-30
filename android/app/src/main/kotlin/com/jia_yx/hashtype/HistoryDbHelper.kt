package com.jia_yx.hashtype

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

class HistoryDbHelper private constructor(context: Context) :
    SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val TAG = "HistoryDbHelper"
        private const val DATABASE_NAME = "hashtype_history.db"
        private const val DATABASE_VERSION = 1

        private const val TABLE_HISTORY = "history"
        private const val COLUMN_ID = "id"
        private const val COLUMN_TIMESTAMP = "timestamp"
        private const val COLUMN_RAW_TEXT = "raw_text"
        private const val COLUMN_PROCESSED_TEXT = "processed_text"
        private const val COLUMN_LLM_USED = "llm_used"

        private const val MAX_RECORDS = 1000

        @Volatile
        private var instance: HistoryDbHelper? = null

        fun getInstance(context: Context): HistoryDbHelper {
            return instance ?: synchronized(this) {
                instance ?: HistoryDbHelper(context.applicationContext).also { instance = it }
            }
        }
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createTable = ("CREATE TABLE " + TABLE_HISTORY + "("
                + COLUMN_ID + " INTEGER PRIMARY KEY AUTOINCREMENT,"
                + COLUMN_TIMESTAMP + " INTEGER,"
                + COLUMN_RAW_TEXT + " TEXT,"
                + COLUMN_PROCESSED_TEXT + " TEXT,"
                + COLUMN_LLM_USED + " INTEGER" + ")")
        db.execSQL(createTable)
        db.execSQL("CREATE INDEX idx_history_timestamp ON $TABLE_HISTORY ($COLUMN_TIMESTAMP DESC)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE_HISTORY")
        onCreate(db)
    }

    @Synchronized
    fun addRecord(rawText: String, processedText: String, llmUsed: Int) {
        try {
            val db = writableDatabase
            val values = ContentValues().apply {
                put(COLUMN_TIMESTAMP, System.currentTimeMillis())
                put(COLUMN_RAW_TEXT, rawText)
                put(COLUMN_PROCESSED_TEXT, processedText)
                put(COLUMN_LLM_USED, llmUsed)
            }
            db.insert(TABLE_HISTORY, null, values)
            trimRecords(db)
        } catch (e: Exception) {
            Log.e(TAG, "Error adding record", e)
        }
    }

    private fun trimRecords(db: SQLiteDatabase) {
        try {
            val query = "SELECT COUNT(*) FROM $TABLE_HISTORY"
            val cursor = db.rawQuery(query, null)
            var count = 0
            if (cursor.moveToFirst()) {
                count = cursor.getInt(0)
            }
            cursor.close()

            if (count > MAX_RECORDS) {
                val deleteCount = count - MAX_RECORDS
                val deleteSubquery = "DELETE FROM $TABLE_HISTORY WHERE $COLUMN_ID IN (" +
                        "SELECT $COLUMN_ID FROM $TABLE_HISTORY ORDER BY $COLUMN_TIMESTAMP ASC LIMIT $deleteCount)"
                db.execSQL(deleteSubquery)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error trimming records", e)
        }
    }

    @Synchronized
    fun getRecords(limit: Int, offset: Int): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        try {
            val db = readableDatabase
            val query = "SELECT * FROM $TABLE_HISTORY ORDER BY $COLUMN_TIMESTAMP DESC LIMIT ? OFFSET ?"
            val cursor = db.rawQuery(query, arrayOf(limit.toString(), offset.toString()))
            
            if (cursor.moveToFirst()) {
                val idIdx = cursor.getColumnIndex(COLUMN_ID)
                val tsIdx = cursor.getColumnIndex(COLUMN_TIMESTAMP)
                val rawIdx = cursor.getColumnIndex(COLUMN_RAW_TEXT)
                val procIdx = cursor.getColumnIndex(COLUMN_PROCESSED_TEXT)
                val llmIdx = cursor.getColumnIndex(COLUMN_LLM_USED)
                
                do {
                    val map = mapOf(
                        "id" to if (idIdx != -1) cursor.getInt(idIdx) else 0,
                        "timestamp" to if (tsIdx != -1) cursor.getLong(tsIdx) else 0L,
                        "raw_text" to if (rawIdx != -1) cursor.getString(rawIdx).orEmpty() else "",
                        "processed_text" to if (procIdx != -1) cursor.getString(procIdx).orEmpty() else "",
                        "llm_used" to if (llmIdx != -1) cursor.getInt(llmIdx) else 0
                    )
                    list.add(map)
                } while (cursor.moveToNext())
            }
            cursor.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting records", e)
        }
        return list
    }

    @Synchronized
    fun deleteRecord(id: Int): Int {
        var deletedRows = 0
        try {
            val db = writableDatabase
            deletedRows = db.delete(TABLE_HISTORY, "$COLUMN_ID = ?", arrayOf(id.toString()))
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting record", e)
        }
        return deletedRows
    }

    @Synchronized
    fun clearAllRecords() {
        try {
            val db = writableDatabase
            db.delete(TABLE_HISTORY, null, null)
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing records", e)
        }
    }

    @Synchronized
    fun searchRecords(searchQuery: String): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        try {
            val db = readableDatabase
            val sql = "SELECT * FROM $TABLE_HISTORY WHERE $COLUMN_RAW_TEXT LIKE ? OR $COLUMN_PROCESSED_TEXT LIKE ? ORDER BY $COLUMN_TIMESTAMP DESC LIMIT 200"
            val likePattern = "%$searchQuery%"
            val cursor = db.rawQuery(sql, arrayOf(likePattern, likePattern))
            
            if (cursor.moveToFirst()) {
                val idIdx = cursor.getColumnIndex(COLUMN_ID)
                val tsIdx = cursor.getColumnIndex(COLUMN_TIMESTAMP)
                val rawIdx = cursor.getColumnIndex(COLUMN_RAW_TEXT)
                val procIdx = cursor.getColumnIndex(COLUMN_PROCESSED_TEXT)
                val llmIdx = cursor.getColumnIndex(COLUMN_LLM_USED)
                
                do {
                    val map = mapOf(
                        "id" to if (idIdx != -1) cursor.getInt(idIdx) else 0,
                        "timestamp" to if (tsIdx != -1) cursor.getLong(tsIdx) else 0L,
                        "raw_text" to if (rawIdx != -1) cursor.getString(rawIdx).orEmpty() else "",
                        "processed_text" to if (procIdx != -1) cursor.getString(procIdx).orEmpty() else "",
                        "llm_used" to if (llmIdx != -1) cursor.getInt(llmIdx) else 0
                    )
                    list.add(map)
                } while (cursor.moveToNext())
            }
            cursor.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error searching records", e)
        }
        return list
    }
}

# API Schema

## POST /transcribeAudio
接收音频并返回转写文本。

### Request
- **Headers:** 
  - `Authorization: Bearer <Firebase_ID_Token>`
- **Content-Type:** `multipart/form-data`
- **Body:**
  - `language`: `auto` | `zh` | `en`
  - `audio`: M4A/AAC 文件

### Response
#### Success (200)
```json
{
  "code": 0,
  "data": {
    "text": "转写结果文本",
    "duration": 2.5
  }
}
```

#### Error (401/403/500)
```json
{
  "code": 401,
  "message": "Unauthorized",
  "data": null
}
```
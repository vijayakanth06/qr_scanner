package com.example.qr_scanner

import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val exportChannel = "qr_scanner/export"
	private val pickFolderRequestCode = 12071
	private var pendingFolderPickerResult: MethodChannel.Result? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, exportChannel)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"pickExportFolder" -> {
						if (pendingFolderPickerResult != null) {
							result.error("busy", "Folder picker is already open", null)
							return@setMethodCallHandler
						}

						pendingFolderPickerResult = result
						val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
							addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
							addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
							addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
							addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
							if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
								putExtra(DocumentsContract.EXTRA_INITIAL_URI, Uri.parse("content://com.android.externalstorage.documents/tree/primary%3ADownload"))
							}
						}
						startActivityForResult(intent, pickFolderRequestCode)
					}

					"writeBytesToTreeUri" -> {
						val treeUriRaw = call.argument<String>("treeUri")
						val fileName = call.argument<String>("fileName")
						val bytes = call.argument<ByteArray>("bytes")

						if (treeUriRaw.isNullOrBlank() || fileName.isNullOrBlank() || bytes == null) {
							result.error("invalid_args", "treeUri, fileName and bytes are required", null)
							return@setMethodCallHandler
						}

						try {
							val treeUri = Uri.parse(treeUriRaw)
							val resolver = applicationContext.contentResolver
							val context = applicationContext

							try {
								resolver.takePersistableUriPermission(
									treeUri,
									Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
								)
							} catch (_: Throwable) {
							}

							val parentDocumentUri = when {
								DocumentsContract.isTreeUri(treeUri) -> {
									val treeDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
									DocumentsContract.buildDocumentUriUsingTree(treeUri, treeDocumentId)
								}
								DocumentsContract.isDocumentUri(context, treeUri) -> treeUri
								else -> {
									result.error(
										"invalid_uri",
										"Unsupported folder URI: $treeUriRaw",
										null,
									)
									return@setMethodCallHandler
								}
							}

							val documentUri = DocumentsContract.createDocument(
								resolver,
								parentDocumentUri,
								"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
								fileName,
							)

							if (documentUri == null) {
								result.error("create_failed", "Could not create destination document", null)
								return@setMethodCallHandler
							}

							resolver.openOutputStream(documentUri, "w")?.use { output ->
								output.write(bytes)
								output.flush()
							} ?: run {
								result.error("open_failed", "Could not open output stream", null)
								return@setMethodCallHandler
							}

							result.success(documentUri.toString())
						} catch (error: Throwable) {
							result.error(
								"write_failed",
								"${error::class.java.simpleName}: ${error.message}",
								null,
							)
						}
					}

					else -> result.notImplemented()
				}
			}
	}

	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		super.onActivityResult(requestCode, resultCode, data)

		if (requestCode != pickFolderRequestCode) return

		val pending = pendingFolderPickerResult
		pendingFolderPickerResult = null

		if (pending == null) return

		if (resultCode != RESULT_OK || data?.data == null) {
			pending.error("cancelled", "Folder selection cancelled", null)
			return
		}

		val uri = data.data!!
		try {
			contentResolver.takePersistableUriPermission(
				uri,
				Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
			)
		} catch (_: Throwable) {
		}

		pending.success(uri.toString())
	}
}

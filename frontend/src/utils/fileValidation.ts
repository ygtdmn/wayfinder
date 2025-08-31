// File validation utility for comprehensive media type support
// Supports: Images, Video, Audio, 3D Models, and HTML files

export interface FileTypeInfo {
	category: "image" | "video" | "audio" | "3d" | "html" | "document";
	mimeTypes: string[];
	extensions: string[];
}

export const SUPPORTED_FILE_TYPES: Record<string, FileTypeInfo> = {
	// Image formats
	image: {
		category: "image",
		mimeTypes: [
			"image/png",
			"image/jpeg",
			"image/jpg",
			"image/jfif",
			"image/pjpeg",
			"image/pjp",
			"image/gif",
			"image/tiff",
			"image/tif",
			"image/svg+xml",
			"image/webp",
			"image/heic",
			"image/heif",
			"image/raw",
		],
		extensions: [
			".png",
			".jpeg",
			".jpg",
			".jfif",
			".pjpeg",
			".pjp",
			".gif",
			".tiff",
			".tif",
			".svg",
			".svgz",
			".webp",
			".heic",
			".raw",
		],
	},

	// Video formats
	video: {
		category: "video",
		mimeTypes: [
			"video/webm",
			"video/mp4",
			"video/mpeg",
			"video/mpg",
			"video/m4v",
			"video/m4p",
			"video/avi",
			"video/mov",
			"video/quicktime",
			"video/mp2",
			"video/mpv",
			"video/wmv",
			"video/x-ms-wmv",
			"video/x-flv",
			"video/x-msvideo",
			"application/x-shockwave-flash",
		],
		extensions: [
			".webm",
			".mp4",
			".mpeg",
			".mpg",
			".m4v",
			".m4p",
			".avi",
			".mov",
			".qt",
			".mp2",
			".mpv",
			".wmv",
			".flv",
			".swf",
		],
	},

	// Audio formats
	audio: {
		category: "audio",
		mimeTypes: [
			"audio/mp3",
			"audio/mpeg",
			"audio/wav",
			"audio/wave",
			"audio/x-wav",
			"audio/opus",
			"audio/ogg",
			"audio/oga",
			"audio/aiff",
			"audio/x-aiff",
			"audio/m4a",
			"audio/x-m4a",
			"audio/wma",
			"audio/x-ms-wma",
			"audio/aac",
			"audio/aif",
			"audio/alac",
		],
		extensions: [
			".mp3",
			".wav",
			".opus",
			".ogg",
			".oga",
			".aiff",
			".aif",
			".m4a",
			".wma",
			".aac",
			".alac",
		],
	},

	// 3D model formats
	"3d": {
		category: "3d",
		mimeTypes: [
			"model/gltf-binary",
			"model/gltf+json",
			"application/octet-stream", // for .vox and other binary formats
			"model/obj",
			"model/fbx",
			"model/x3d+xml",
		],
		extensions: [
			".glb",
			".gltf",
			".vox",
			".obj",
			".fbx",
			".dae",
			".3ds",
			".blend",
		],
	},

	// HTML and document formats
	html: {
		category: "html",
		mimeTypes: [
			"text/html",
			"application/xhtml+xml",
			"text/x-server-parsed-html",
			"application/pdf",
		],
		extensions: [".html", ".htm", ".shtml", ".shtm", ".ehtml", ".pdf"],
	},

	// JSON and data formats
	json: {
		category: "document",
		mimeTypes: [
			"application/json",
			"text/json",
			"application/ld+json",
		],
		extensions: [".json", ".jsonl", ".ndjson"],
	},
};

// Comprehensive list of all supported extensions
export const ALL_SUPPORTED_EXTENSIONS = Object.values(SUPPORTED_FILE_TYPES)
	.flatMap((type) => type.extensions)
	.sort();

// Comprehensive list of all supported MIME types
export const ALL_SUPPORTED_MIME_TYPES = Object.values(SUPPORTED_FILE_TYPES)
	.flatMap((type) => type.mimeTypes)
	.sort();

/**
 * Get file category from extension
 */
export function getFileCategory(extension: string): string | null {
	const ext = extension.toLowerCase();

	for (const [category, info] of Object.entries(SUPPORTED_FILE_TYPES)) {
		if (info.extensions.includes(ext)) {
			return category;
		}
	}

	return null;
}

/**
 * Get file category from MIME type
 */
export function getFileCategoryFromMime(mimeType: string): string | null {
	const mime = mimeType.toLowerCase();

	for (const [category, info] of Object.entries(SUPPORTED_FILE_TYPES)) {
		if (info.mimeTypes.includes(mime)) {
			return category;
		}
	}

	return null;
}

/**
 * Validate if file is supported
 */
export function isFileSupported(file: File): boolean {
	// Check by MIME type first
	if (getFileCategoryFromMime(file.type)) {
		return true;
	}

	// Check by extension as fallback
	const extension = "." + file.name.split(".").pop()?.toLowerCase();
	return getFileCategory(extension) !== null;
}

/**
 * Get file type info
 */
export function getFileInfo(file: File): {
	category: string | null;
	isSupported: boolean;
	extension: string;
} {
	const extension = "." + file.name.split(".").pop()?.toLowerCase();
	const categoryFromMime = getFileCategoryFromMime(file.type);
	const categoryFromExt = getFileCategory(extension);

	return {
		category: categoryFromMime || categoryFromExt,
		isSupported: isFileSupported(file),
		extension,
	};
}

/**
 * Generate accept attribute for file input
 */
export function getAcceptAttribute(): string {
	return ALL_SUPPORTED_EXTENSIONS.join(",");
}

/**
 * Generate accept attribute for thumbnail input (images and SVG only)
 */
export function getThumbnailAcceptAttribute(): string {
	return SUPPORTED_FILE_TYPES.image.extensions.join(",");
}

/**
 * Validate if file is supported for thumbnails (images and SVG only)
 */
export function isThumbnailSupported(file: File): boolean {
	// Check by MIME type first
	if (SUPPORTED_FILE_TYPES.image.mimeTypes.includes(file.type.toLowerCase())) {
		return true;
	}

	// Check by extension as fallback
	const extension = "." + file.name.split(".").pop()?.toLowerCase();
	return SUPPORTED_FILE_TYPES.image.extensions.includes(extension);
}

/**
 * Get human-readable error message for unsupported files
 */
export function getUnsupportedFileMessage(file: File): string {
	const { extension } = getFileInfo(file);
	return `File type "${extension}" is not supported. Please use: Image, video, audio, 3D model, or HTML files.`;
}

/**
 * Get human-readable error message for unsupported thumbnail files
 */
export function getUnsupportedThumbnailMessage(file: File): string {
	const { extension } = getFileInfo(file);
	return `File type "${extension}" is not supported for thumbnails. Please use image files (PNG, JPG, GIF, SVG, WebP, etc.).`;
}

import { useState, useEffect } from "react";
import { getFileInfo } from "../utils/fileValidation";
import { useTheme } from "../hooks/useTheme";

interface FilePreviewProps {
	file: File | null;
	previewUrl: string;
	className?: string;
	maxHeight?: string;
}

export default function FilePreview({
	file,
	previewUrl,
	className = "",
	maxHeight = "max-h-64",
}: FilePreviewProps) {
	const { isDarkMode } = useTheme();
	const [htmlContent, setHtmlContent] = useState<string>("");
	const [isHtmlLoading, setIsHtmlLoading] = useState(false);

	useEffect(() => {
		if (file && getFileInfo(file).category === "html") {
			setIsHtmlLoading(true);
			const reader = new FileReader();
			reader.onload = (e) => {
				setHtmlContent(e.target?.result as string);
				setIsHtmlLoading(false);
			};
			reader.readAsText(file);
		}
	}, [file]);

	if (!file || !previewUrl) {
		return null;
	}

	const fileInfo = getFileInfo(file);
	const { category } = fileInfo;

	const renderPreview = () => {
		switch (category) {
			case "image":
				return (
					<img
						src={previewUrl}
						alt="Preview"
						className={`${maxHeight} mx-auto object-contain`}
					/>
				);

			case "video":
				return (
					<video
						src={previewUrl}
						controls
						className={`${maxHeight} mx-auto`}
						preload="metadata"
						onClick={(e) => e.stopPropagation()}
					>
						Your browser does not support the video element.
					</video>
				);

			case "audio":
				return (
					<div className="text-center space-y-4">
						<div className={`w-24 h-24 mx-auto ${isDarkMode ? 'bg-zinc-700' : 'bg-zinc-300'} rounded-lg flex items-center justify-center`}>
							<svg
								className={`w-12 h-12 ${isDarkMode ? 'text-zinc-400' : 'text-zinc-600'}`}
								fill="none"
								stroke="currentColor"
								viewBox="0 0 24 24"
							>
								<path
									strokeLinecap="round"
									strokeLinejoin="round"
									strokeWidth={2}
									d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"
								/>
							</svg>
						</div>
						<audio
							src={previewUrl}
							controls
							className="w-full max-w-sm mx-auto"
							onClick={(e) => e.stopPropagation()}
						>
							Your browser does not support the audio element.
						</audio>
					</div>
				);

			case "html":
				return (
					<div className="space-y-4">
						{isHtmlLoading ? (
							<div className="text-center py-8">
								<div className={`animate-spin w-6 h-6 border-2 ${isDarkMode ? 'border-zinc-600 border-t-white' : 'border-zinc-300 border-t-black'} rounded-full mx-auto`}></div>
								<p className={`${isDarkMode ? 'text-zinc-400' : 'text-zinc-600'} mt-2`}>Loading HTML preview...</p>
							</div>
						) : (
							<>
								<div className={`${isDarkMode ? 'bg-zinc-800 border-zinc-700' : 'bg-zinc-100 border-zinc-300'} border rounded-lg p-4 max-h-64 overflow-auto`}>
									<iframe
										srcDoc={htmlContent}
										className="w-full h-48 border-0 bg-white rounded"
										title="HTML Preview"
										sandbox="allow-scripts allow-same-origin"
										onClick={(e) => e.stopPropagation()}
									/>
								</div>
								<details
									className="text-left"
									onClick={(e) => e.stopPropagation()}
								>
									<summary className={`text-sm ${isDarkMode ? 'text-zinc-400 hover:text-zinc-300' : 'text-zinc-600 hover:text-zinc-800'} cursor-pointer`}>
										View HTML source
									</summary>
									<pre className={`text-xs ${isDarkMode ? 'text-zinc-500 bg-zinc-900' : 'text-zinc-600 bg-zinc-50'} mt-2 p-3 rounded border overflow-auto max-h-32`}>
										<code>
											{htmlContent.slice(0, 1000)}
											{htmlContent.length > 1000 ? "..." : ""}
										</code>
									</pre>
								</details>
							</>
						)}
					</div>
				);

			case "3d":
				return (
					<div className="text-center space-y-4">
						<div className={`w-32 h-32 mx-auto ${isDarkMode ? 'bg-zinc-700' : 'bg-zinc-300'} rounded-lg flex items-center justify-center`}>
							<svg
								className={`w-16 h-16 ${isDarkMode ? 'text-zinc-400' : 'text-zinc-600'}`}
								fill="none"
								stroke="currentColor"
								viewBox="0 0 24 24"
							>
								<path
									strokeLinecap="round"
									strokeLinejoin="round"
									strokeWidth={2}
									d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"
								/>
							</svg>
						</div>
						<p className={`${isDarkMode ? 'text-zinc-300' : 'text-zinc-700'} font-medium`}>3D Model File</p>
						<p className={`text-sm ${isDarkMode ? 'text-zinc-400' : 'text-zinc-600'}`}>
							{file.name} • {(file.size / 1024).toFixed(1)} KB
						</p>
					</div>
				);

			default:
				return (
					<div className="text-center space-y-4">
						<div className={`w-32 h-32 mx-auto ${isDarkMode ? 'bg-zinc-700' : 'bg-zinc-300'} rounded-lg flex items-center justify-center`}>
							<svg
								className={`w-16 h-16 ${isDarkMode ? 'text-zinc-400' : 'text-zinc-600'}`}
								fill="none"
								stroke="currentColor"
								viewBox="0 0 24 24"
							>
								<path
									strokeLinecap="round"
									strokeLinejoin="round"
									strokeWidth={2}
									d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
								/>
							</svg>
						</div>
						<p className={`${isDarkMode ? 'text-zinc-300' : 'text-zinc-700'} font-medium`}>
							{category?.toUpperCase()} File
						</p>
						<p className={`text-sm ${isDarkMode ? 'text-zinc-400' : 'text-zinc-600'}`}>
							{file.name} • {(file.size / 1024).toFixed(1)} KB
						</p>
					</div>
				);
		}
	};

	return (
		<div
			className={`space-y-4 ${className}`}
			onClick={(e) => e.stopPropagation()}
		>
			{renderPreview()}
			<div className={`text-sm ${isDarkMode ? 'text-zinc-400' : 'text-zinc-600'} text-left`}>
				<p>File: {file.name}</p>
				<p>Type: {file.type || "Unknown"}</p>
				<p>Size: {(file.size / 1024).toFixed(1)} KB</p>
				<p>Category: {category || "Unknown"}</p>
			</div>
		</div>
	);
}

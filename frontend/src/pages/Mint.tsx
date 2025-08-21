import { useMemo, useState, useCallback, useEffect } from "react";
import { useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { useSearchParams, useNavigate, Link } from "react-router-dom";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import type { Address } from "viem";
import { multiplexAbi } from "../abis/multiplex-abi";
import fastlz from "../lib/fastlz";
import { sha256 } from "js-sha256";
import {
	isFileSupported,
	getAcceptAttribute,
	getUnsupportedFileMessage,
	getFileInfo,
	isThumbnailSupported,
	getThumbnailAcceptAttribute,
	getUnsupportedThumbnailMessage,
} from "../utils/fileValidation";
import FilePreview from "../components/FilePreview";
import type { Attribute } from "../types/metadata";

export default function Mint() {
	const [sp] = useSearchParams();
	const navigate = useNavigate();
	const creator = (sp.get("creator") || "") as Address;
	const type = sp.get("type") || "Unknown";

	// Artwork file
	const [artworkFile, setArtworkFile] = useState<File | null>(null);
	const [artworkPreview, setArtworkPreview] = useState<string>("");
	const [imageHash, setImageHash] = useState("");
	const [imageMimeType, setImageMimeType] = useState("");

	// Metadata
	const [name, setName] = useState("");
	const [description, setDescription] = useState("");
	const [externalUrl, setExternalUrl] = useState("");
	const [attributes, setAttributes] = useState<Attribute[]>([]);

	// Display preferences
	const [displayMode, setDisplayMode] = useState(1);
	const [isAnimationUri, setIsAnimationUri] = useState(false);
	const [useOffchainThumbnail, setUseOffchainThumbnail] = useState(true);

	// Collector permissions
	const [allowAddArtwork, setAllowAddArtwork] = useState(true);
	const [allowSelectArtwork, setAllowSelectArtwork] = useState(true);
	const [allowSelectThumb, setAllowSelectThumb] = useState(true);
	const [allowToggleDisplay, setAllowToggleDisplay] = useState(true);

	// Thumbnail
	const [thumbnailFile, setThumbnailFile] = useState<File | null>(null);
	const [thumbnailPreview, setThumbnailPreview] = useState<string>("");
	const [thumbMime, setThumbMime] = useState("");
	const [thumbLength, setThumbLength] = useState<number>(0);
	const [thumbChunks, setThumbChunks] = useState<string[]>([]);

	// Additional URIs
	const [artistArtworkUris, setArtistArtworkUris] = useState<string>("");
	const [artistThumbnailUris, setArtistThumbnailUris] = useState<string>("");

	// Recipients
	const [recipients, setRecipients] = useState<string>("");
	const [quantities, setQuantities] = useState<string>("");

	// Transaction state
	const {
		data: hash,
		isPending,
		writeContract,
		error: writeError,
	} = useWriteContract();
	const {
		isLoading: isConfirming,
		isSuccess,
		error: receiptError,
	} = useWaitForTransactionReceipt({
		hash,
	});

	// Debug transaction errors
	useEffect(() => {
		if (writeError) {
			console.error("=== WRITE CONTRACT ERROR ===");
			console.error("Error:", writeError);
			console.error("Error message:", writeError.message);
			console.error("Error cause:", writeError.cause);
		}
	}, [writeError]);

	useEffect(() => {
		if (receiptError) {
			console.error("=== RECEIPT ERROR ===");
			console.error("Error:", receiptError);
			console.error("Error message:", receiptError.message);
		}
	}, [receiptError]);

	const handleArtworkFile = useCallback(async (file: File) => {
		setArtworkFile(file);
		setImageMimeType(file.type);

		// Create preview
		const reader = new FileReader();
		reader.onload = (e) => setArtworkPreview(e.target?.result as string);
		reader.readAsDataURL(file);

		// Calculate hash
		const buffer = await file.arrayBuffer();
		const hash = sha256.hex(new Uint8Array(buffer));
		setImageHash(`0x${hash}`);

		// Auto-determine animation URI based on file type
		const fileInfo = getFileInfo(file);
		const isStaticImage =
			fileInfo.category === "image" && !file.type.includes("gif");
		setIsAnimationUri(!isStaticImage);
	}, []);

	const prepareThumbnail = useCallback(async (file: File) => {
		setThumbnailFile(file);
		setThumbMime(file.type);

		// Create preview
		const reader = new FileReader();
		reader.onload = (e) => setThumbnailPreview(e.target?.result as string);
		reader.readAsDataURL(file);

		// Compress and chunk
		const buffer = await file.arrayBuffer();
		const compressed = fastlz.compress(new Uint8Array(buffer));
		setThumbLength(buffer.byteLength);

		const CHUNK_SIZE = 23 * 1024; // 23KB per chunk
		const chunks: string[] = [];
		for (let i = 0; i < compressed.length; i += CHUNK_SIZE) {
			const chunk = compressed.slice(i, i + CHUNK_SIZE);
			chunks.push(
				`0x${Array.from(chunk)
					.map((b) => (b as number).toString(16).padStart(2, "0"))
					.join("")}`
			);
		}
		setThumbChunks(chunks);
	}, []);

	const handleAddAttribute = () => {
		setAttributes([...attributes, { trait_type: "", value: "" }]);
	};

	const handleAttributeChange = (
		index: number,
		field: keyof Attribute,
		value: string | number
	) => {
		const newAttributes = [...attributes];
		if (field === "display_type" && typeof value === "string") {
			// Type guard for display_type
			const validDisplayTypes = [
				"number",
				"boost_number",
				"boost_percentage",
				"date",
			] as const;
			if (
				validDisplayTypes.includes(value as (typeof validDisplayTypes)[number])
			) {
				// @ts-expect-error - dynamic field assignment
				newAttributes[index][field] = value;
			}
		} else if (field !== "display_type") {
			// @ts-expect-error - dynamic field assignment
			newAttributes[index][field] = value;
		}
		setAttributes(newAttributes);
	};

	const handleRemoveAttribute = (index: number) => {
		setAttributes(attributes.filter((_, i) => i !== index));
	};

	const recipientsArr = useMemo(
		() =>
			recipients
				.split(",")
				.map((s) => s.trim())
				.filter(Boolean) as Address[],
		[recipients]
	);
	const quantitiesArr = useMemo(
		() =>
			quantities
				.split(",")
				.map((s) => s.trim())
				.filter(Boolean)
				.map((n) => BigInt(n)),
		[quantities]
	);

	const metadataJson = useMemo(() => {
		const fields: string[] = [];
		if (name) fields.push(`"name":${JSON.stringify(name)}`);
		if (description)
			fields.push(`"description":${JSON.stringify(description)}`);
		if (externalUrl)
			fields.push(`"external_url":${JSON.stringify(externalUrl)}`);
		if (attributes.length > 0) {
			const validAttrs = attributes
				.filter((a) => a.trait_type && a.value !== "")
				.map((attr) => {
					const parts = [
						`"trait_type":${JSON.stringify(attr.trait_type)}`,
						`"value":${JSON.stringify(attr.value)}`,
					];
					if (attr.display_type) {
						parts.push(`"display_type":${JSON.stringify(attr.display_type)}`);
					}
					return `{${parts.join(",")}}`;
				});
			if (validAttrs.length > 0) {
				fields.push(`"attributes":[${validAttrs.join(",")}]`);
			}
		}
		// IMPORTANT: return inner JSON (no outer braces). Contract wraps it.
		return fields.join(",");
	}, [name, description, externalUrl, attributes]);

	const baseParams = useMemo(
		() => ({
			metadata: metadataJson,
			onChainThumbnail: {
				mimeType: thumbMime,
				chunks: [], // Empty - contract will populate with SSTORE2 addresses
				length: BigInt(thumbLength || 0),
				zipped: true,
				deflated: false,
			},
			initialDisplayMode: displayMode,
			immutableProperties: {
				imageHash,
				imageMimeType,
				isAnimationUri,
				useOffchainThumbnail,
				allowCollectorAddArtwork: allowAddArtwork,
				allowCollectorSelectArtistArtwork: allowSelectArtwork,
				allowCollectorSelectArtistThumbnail: allowSelectThumb,
				allowCollectorToggleDisplayMode: allowToggleDisplay,
			},
			seedArtistArtworkUris: (artistArtworkUris
				? artistArtworkUris
						.split("\n")
						.map((s) => s.trim())
						.filter(Boolean)
				: []) as readonly string[],
			seedArtistThumbnailUris: (artistThumbnailUris
				? artistThumbnailUris
						.split("\n")
						.map((s) => s.trim())
						.filter(Boolean)
				: []) as readonly string[],
		}),
		[
			metadataJson,
			thumbMime,
			thumbLength,
			displayMode,
			imageHash,
			imageMimeType,
			isAnimationUri,
			useOffchainThumbnail,
			allowAddArtwork,
			allowSelectArtwork,
			allowSelectThumb,
			allowToggleDisplay,
			artistArtworkUris,
			artistThumbnailUris,
		]
	);

	const onSubmit = (e: React.FormEvent) => {
		e.preventDefault();

		console.log("=== MINT DEBUG START ===");
		console.log("Creator:", creator);
		console.log("Type:", type);
		console.log("Name:", name);
		console.log("Recipients:", recipients);
		console.log("Recipients array:", recipientsArr);
		console.log("Quantities:", quantities);
		console.log("Quantities array:", quantitiesArr);
		console.log("Base params:", baseParams);
		console.log("Thumb chunks count:", thumbChunks.length);
		console.log("Metadata JSON:", metadataJson);
		console.log("Image hash:", imageHash);
		console.log("Artwork file:", artworkFile);
		console.log(
			"Button disabled?",
			!name || recipientsArr.length === 0 || isPending || isConfirming
		);
		console.log("isPending:", isPending);
		console.log("isConfirming:", isConfirming);
		console.log("WriteError:", writeError);
		console.log("ReceiptError:", receiptError);

		// Validation checks
		if (!name) console.warn("❌ Missing name");
		if (recipientsArr.length === 0) console.warn("❌ No recipients");
		if (!artworkFile) console.warn("⚠️  No artwork file");
		if (!imageHash) console.warn("⚠️  No image hash");
		if (type === "ERC1155" && quantitiesArr.length !== recipientsArr.length) {
			console.warn("❌ Recipients/quantities length mismatch");
		}

		try {
			if (type === "ERC1155") {
				const params = {
					baseParams,
					recipients: recipientsArr,
					quantities: quantitiesArr,
				};
				console.log("ERC1155 params:", params);
				console.log("About to call writeContract for ERC1155...");
				writeContract({
					abi: multiplexAbi,
					address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
					functionName: "mintERC1155",
					args: [creator, params, thumbChunks as readonly `0x${string}`[]],
					value: 0n,
				});
			} else {
				const params = {
					baseParams,
					recipients: recipientsArr,
				};
				console.log("ERC721 params:", params);
				console.log("About to call writeContract for ERC721...");
				writeContract({
					abi: multiplexAbi,
					address: import.meta.env.VITE_MULTIPLEX_ADDRESS as Address,
					functionName: "mintERC721",
					args: [creator, params, thumbChunks as readonly `0x${string}`[]],
					value: 0n,
				});
			}
			console.log("writeContract called successfully");
		} catch (error) {
			console.error("Error in onSubmit:", error);
		}
		console.log("=== MINT DEBUG END ===");
	};

	if (!creator) {
		return (
			<div className="text-center py-12">
				<p className="text-zinc-400">Please select a collection first.</p>
				<button
					onClick={() => navigate("/collections")}
					className="btn-primary mt-4"
				>
					Go to Collections
				</button>
			</div>
		);
	}

	if (isSuccess) {
		return (
			<div className="max-w-2xl mx-auto text-center py-12 animate-fade-in">
				<div className="inline-flex items-center justify-center w-16 h-16 bg-success bg-opacity-10 mb-4">
					<svg
						className="w-8 h-8 text-success"
						fill="none"
						stroke="currentColor"
						viewBox="0 0 24 24"
					>
						<path
							strokeLinecap="round"
							strokeLinejoin="round"
							strokeWidth={2}
							d="M5 13l4 4L19 7"
						/>
					</svg>
				</div>
				<h2 className="text-2xl font-display font-bold text-zinc-100 mb-2">
					Artwork Created!
				</h2>
				<p className="text-zinc-400 mb-8">
					Your artwork has been successfully minted.
				</p>
				<div className="flex gap-3 justify-center">
					<button
						onClick={() => navigate("/collections")}
						className="btn-secondary"
					>
						Back to Collections
					</button>
					<button
						onClick={() => window.location.reload()}
						className="btn-primary"
					>
						Create Another
					</button>
				</div>
			</div>
		);
	}

	return (
		<div className="min-h-screen">
			<div className="flex justify-between items-center p-8 border-b border-zinc-800">
				<Link to="/" className="text-2xl font-black text-zinc-100">
					multiplex
				</Link>
				<ConnectButton />
			</div>
			<form
				onSubmit={onSubmit}
				className="max-w-4xl mx-auto px-8 py-8 space-y-8 animate-fade-in"
			>
				<div>
					<h2 className="text-2xl font-display font-bold text-zinc-100">
						Create New Artwork
					</h2>
					<p className="text-zinc-400 mt-1">
						Fill in the details for your{" "}
						{type === "ERC1155" ? "multiple edition" : "single edition"} NFT
					</p>
				</div>

				{/* Step 1: Artwork */}
				<div className="card">
					<h3 className="text-lg font-semibold text-zinc-100 mb-4">
						1. Upload Your Artwork
					</h3>
					<div
						className={`upload-zone ${artworkFile ? "active" : ""}`}
						onDragOver={(e) => {
							e.preventDefault();
							e.currentTarget.classList.add("active");
						}}
						onDragLeave={(e) => {
							e.currentTarget.classList.remove("active");
						}}
						onDrop={(e) => {
							e.preventDefault();
							e.currentTarget.classList.remove("active");
							const file = e.dataTransfer.files?.[0];
							if (file && isFileSupported(file)) {
								handleArtworkFile(file);
							} else if (file) {
								alert(getUnsupportedFileMessage(file));
							}
						}}
						onClick={() => {
							const input = document.createElement("input");
							input.type = "file";
							input.accept = getAcceptAttribute();
							input.onchange = () => {
								const file = input.files?.[0];
								if (file && isFileSupported(file)) {
									handleArtworkFile(file);
								} else if (file) {
									alert(getUnsupportedFileMessage(file));
								}
							};
							input.click();
						}}
					>
						{artworkPreview ? (
							<div className="space-y-4">
								<FilePreview
									file={artworkFile}
									previewUrl={artworkPreview}
									maxHeight="max-h-64"
								/>
								<p className="font-mono text-xs text-zinc-400 text-left">
									Hash: {imageHash}
								</p>
							</div>
						) : (
							<>
								<svg
									className="w-12 h-12 text-gray-400 mx-auto mb-4"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
								>
									<path
										strokeLinecap="round"
										strokeLinejoin="round"
										strokeWidth={2}
										d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
									/>
								</svg>
								<p className="text-zinc-300">
									Drop your artwork here or click to browse
								</p>
								<p className="text-sm text-zinc-400 mt-2">
									Image, video, audio, 3D model, html
								</p>
							</>
						)}
					</div>
				</div>

				{/* Step 2: Details */}
				<div className="card">
					<h3 className="text-lg font-semibold text-zinc-100 mb-4">
						2. Artwork Details
					</h3>
					<div className="space-y-4">
						<div>
							<label className="label">Title *</label>
							<input
								className="input-field"
								placeholder="My Amazing Artwork"
								value={name}
								onChange={(e) => setName(e.target.value)}
								required
							/>
						</div>
						<div>
							<label className="label">Description</label>
							<textarea
								rows={4}
								className="textarea-field"
								placeholder="Tell the story behind your artwork..."
								value={description}
								onChange={(e) => setDescription(e.target.value)}
							/>
						</div>
						<div>
							<label className="label">External Link</label>
							<input
								className="input-field"
								placeholder="https://yourwebsite.com"
								value={externalUrl}
								onChange={(e) => setExternalUrl(e.target.value)}
							/>
							<p className="help-text">Link to your website or social media</p>
						</div>
					</div>

					<div className="mt-6">
						<label className="label">Properties</label>
						<p className="help-text mb-3">
							Add attributes that describe your artwork
						</p>
						{attributes.map((attr, index) => (
							<div key={index} className="flex gap-2 mb-2">
								<input
									className="input-field flex-1"
									placeholder="Property"
									value={attr.trait_type}
									onChange={(e) =>
										handleAttributeChange(index, "trait_type", e.target.value)
									}
								/>
								<input
									className="input-field flex-1"
									placeholder="Value"
									value={attr.value}
									onChange={(e) =>
										handleAttributeChange(index, "value", e.target.value)
									}
								/>
								<button
									type="button"
									onClick={() => handleRemoveAttribute(index)}
									className="btn-ghost"
								>
									<svg
										className="w-5 h-5"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
									>
										<path
											strokeLinecap="round"
											strokeLinejoin="round"
											strokeWidth={2}
											d="M6 18L18 6M6 6l12 12"
										/>
									</svg>
								</button>
							</div>
						))}
						<button
							type="button"
							onClick={handleAddAttribute}
							className="btn-secondary text-sm"
						>
							+ Add Property
						</button>
					</div>
				</div>

				{/* Step 3: Artwork Options */}
				<div className="card">
					<h3 className="text-lg font-semibold text-zinc-100 mb-4">
						3. Artwork Options
					</h3>
					<div className="space-y-4">
						<div>
							<label className="label">Display Mode</label>
							<select
								className="input-field"
								value={displayMode}
								onChange={(e) => setDisplayMode(Number(e.target.value))}
							>
								<option value={0}>Image</option>
								<option value={1}>Interactive HTML</option>
							</select>
							<p className="help-text">
								How the artwork will be displayed by default
							</p>
						</div>

						<div>
							<label className="label">Additional Artwork URIs</label>
							<textarea
								rows={3}
								className="textarea-field font-mono text-sm"
								placeholder="ipfs://artwork1&#10;ipfs://artwork2"
								value={artistArtworkUris}
								onChange={(e) => setArtistArtworkUris(e.target.value)}
							/>
							<p className="help-text">
								One URI per line. Collectors can select from these artworks.
							</p>
						</div>

						<div>
							<label className="label">Thumbnail Options</label>
							<div className="space-y-3">
								<label className="flex items-center gap-3">
									<input
										type="checkbox"
										checked={!useOffchainThumbnail}
										onChange={(e) => setUseOffchainThumbnail(!e.target.checked)}
										className="checkbox"
									/>
									<span className="text-zinc-300">
										Include on-chain thumbnail in metadata
									</span>
								</label>
							</div>
						</div>

						{!useOffchainThumbnail && (
							<div>
								<label className="label">On-chain Thumbnail (optional)</label>
								<div
									className={`upload-zone ${thumbnailFile ? "active" : ""}`}
									onDragOver={(e) => {
										e.preventDefault();
										e.currentTarget.classList.add("active");
									}}
									onDragLeave={(e) => {
										e.currentTarget.classList.remove("active");
									}}
									onDrop={(e) => {
										e.preventDefault();
										e.currentTarget.classList.remove("active");
										const file = e.dataTransfer.files?.[0];
										if (file && isThumbnailSupported(file)) {
											prepareThumbnail(file);
										} else if (file) {
											alert(getUnsupportedThumbnailMessage(file));
										}
									}}
									onClick={() => {
										const input = document.createElement("input");
										input.type = "file";
										input.accept = getThumbnailAcceptAttribute();
										input.onchange = () => {
											const file = input.files?.[0];
											if (file && isThumbnailSupported(file)) {
												prepareThumbnail(file);
											} else if (file) {
												alert(getUnsupportedThumbnailMessage(file));
											}
										};
										input.click();
									}}
								>
									{thumbnailPreview ? (
										<div className="space-y-2">
											<FilePreview
												file={thumbnailFile}
												previewUrl={thumbnailPreview}
												maxHeight="max-h-32"
											/>
											<p className="text-sm text-zinc-400 text-center">
												{thumbChunks.length} chunks • {thumbLength} bytes
												original
											</p>
										</div>
									) : (
										<p className="text-zinc-400 text-sm">
											Drop a thumbnail file or click to browse
										</p>
									)}
								</div>
							</div>
						)}

						{useOffchainThumbnail && (
							<div>
								<label className="label">Thumbnail URIs</label>
								<textarea
									rows={3}
									className="textarea-field font-mono text-sm"
									placeholder="ipfs://thumb1&#10;ipfs://thumb2"
									value={artistThumbnailUris}
									onChange={(e) => setArtistThumbnailUris(e.target.value)}
								/>
								<p className="help-text">
									One URI per line. Collectors can select from these thumbnails.
								</p>
							</div>
						)}
					</div>
				</div>

				{/* Step 4: Collector Permissions */}
				<div className="card">
					<h3 className="text-lg font-semibold text-zinc-100 mb-4">
						4. Collector Permissions
					</h3>
					<p className="text-zinc-400 mb-4">
						What can collectors do with your artwork?
					</p>
					<div className="space-y-3">
						<label className="flex items-center gap-3">
							<input
								type="checkbox"
								checked={allowAddArtwork}
								onChange={(e) => setAllowAddArtwork(e.target.checked)}
								className="checkbox"
							/>
							<span className="text-zinc-300">
								Add their own artwork (HTML mode only)
							</span>
						</label>
						<label className="flex items-center gap-3">
							<input
								type="checkbox"
								checked={allowSelectArtwork}
								onChange={(e) => setAllowSelectArtwork(e.target.checked)}
								className="checkbox"
							/>
							<span className="text-zinc-300">
								Select from artist-provided artworks
							</span>
						</label>
						{useOffchainThumbnail && (
							<label className="flex items-center gap-3">
								<input
									type="checkbox"
									checked={allowSelectThumb}
									onChange={(e) => setAllowSelectThumb(e.target.checked)}
									className="checkbox"
								/>
								<span className="text-zinc-300">
									Select from artist-provided thumbnails
								</span>
							</label>
						)}
						<label className="flex items-center gap-3">
							<input
								type="checkbox"
								checked={allowToggleDisplay}
								onChange={(e) => setAllowToggleDisplay(e.target.checked)}
								className="checkbox"
							/>
							<span className="text-zinc-300">
								Toggle between display modes
							</span>
						</label>
					</div>
				</div>

				{/* Step 5: Recipients */}
				<div className="card">
					<h3 className="text-lg font-semibold text-zinc-100 mb-4">
						{type === "ERC1155"
							? "5. Recipients & Quantities"
							: "5. Recipients"}
					</h3>
					<div className="space-y-4">
						<div>
							<label className="label">Recipient Addresses *</label>
							<input
								className="input-field font-mono text-sm"
								placeholder="0x123..., 0x456..."
								value={recipients}
								onChange={(e) => setRecipients(e.target.value)}
								required
							/>
							<p className="help-text">Comma-separated wallet addresses</p>
						</div>
						{type === "ERC1155" && (
							<div>
								<label className="label">Quantities *</label>
								<input
									className="input-field"
									placeholder="1, 5, 10"
									value={quantities}
									onChange={(e) => setQuantities(e.target.value)}
									required
								/>
								<p className="help-text">
									One quantity per recipient, comma-separated
								</p>
							</div>
						)}
					</div>
				</div>

				{/* Submit */}
				<div className="flex justify-end gap-3">
					<button
						type="button"
						onClick={() => navigate("/collections")}
						className="btn-secondary"
					>
						Cancel
					</button>
					<button
						type="submit"
						className="btn-primary"
						disabled={
							!name || recipientsArr.length === 0 || isPending || isConfirming
						}
					>
						{isPending || isConfirming ? (
							<>
								<svg
									className="animate-spin -ml-1 mr-2 h-4 w-4 text-black inline"
									fill="none"
									viewBox="0 0 24 24"
								>
									<circle
										className="opacity-25"
										cx="12"
										cy="12"
										r="10"
										stroke="currentColor"
										strokeWidth="4"
									></circle>
									<path
										className="opacity-75"
										fill="currentColor"
										d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
									></path>
								</svg>
								{isPending ? "Creating..." : "Confirming..."}
							</>
						) : (
							"Create Artwork"
						)}
					</button>
				</div>

				{hash && !isSuccess && (
					<div className="text-center text-sm text-zinc-400">
						Transaction submitted. Waiting for confirmation...
					</div>
				)}

				{writeError && (
					<div className="card bg-red-500 bg-opacity-10 border-red-500 border-opacity-30">
						<div className="text-center py-4">
							<h3 className="text-lg text-red-300 mb-2">Transaction Error</h3>
							<p className="text-red-200 text-sm mb-2">{writeError.message}</p>
							<details className="text-left text-xs text-red-300">
								<summary className="cursor-pointer">Show details</summary>
								<pre className="mt-2 p-2 bg-red-900 bg-opacity-20 rounded overflow-auto">
									{JSON.stringify(writeError, null, 2)}
								</pre>
							</details>
						</div>
					</div>
				)}

				{receiptError && (
					<div className="card bg-red-500 bg-opacity-10 border-red-500 border-opacity-30">
						<div className="text-center py-4">
							<h3 className="text-lg text-red-300 mb-2">Receipt Error</h3>
							<p className="text-red-200 text-sm">{receiptError.message}</p>
						</div>
					</div>
				)}
			</form>
		</div>
	);
}

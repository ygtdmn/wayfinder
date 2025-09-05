import { Link } from "react-router-dom";
import { useState } from "react";
import Header from "../components/Header";
import { useTheme } from "../hooks/useTheme";
import Footer from "../components/Footer";

export default function Home() {
	const [openSections, setOpenSections] = useState<Record<string, boolean>>({
		overview: false,
		uris: false,
		architecture: false,
		permissions: false,
	});

	const { isDarkMode, toggleTheme } = useTheme();

	const toggleSection = (section: string) => {
		setOpenSections((prev) => ({
			...prev,
			[section]: !prev[section],
		}));
	};
	return (
		<div
			className={`scroll-smooth min-h-screen flex flex-col ${
				isDarkMode ? "bg-zinc-950 text-zinc-100" : "bg-zinc-50 text-zinc-900"
			}`}
		>
			<Header
				isDarkMode={isDarkMode}
				toggleTheme={toggleTheme}
				hideConnectButton={true}
			/>

			{/* Centered Content Container */}
			<div className="flex-grow flex items-center justify-center p-4">
				<div className="flex flex-col items-center gap-8 max-w-6xl w-full">
					{/* Header */}
					<div className="px-4 md:px-8 py-12 md:py-16 text-center">
						<div className="max-w-4xl mx-auto">
							<h1
								className={`text-3xl md:text-4xl lg:text-5xl font-bold tracking-tight mb-4 md:mb-6 ${
									isDarkMode ? "text-zinc-100" : "text-zinc-900"
								}`}
							>
								Wayfinder
							</h1>

							<p
								className={`text-sm md:text-base lg:text-lg font-medium mb-6 md:mb-8 ${
									isDarkMode ? "text-zinc-300" : "text-zinc-600"
								}`}
							>
								Create NFTs using Wayfinder's multi-URI storage system via
								Manifold
							</p>

							<Link
								to="/collections"
								className={`inline-block text-xs md:text-sm font-medium border px-4 md:px-6 py-2 md:py-3 transition-all uppercase tracking-wide ${
									isDarkMode
										? "text-zinc-950 bg-zinc-100 border-zinc-100 hover:bg-white"
										: "text-zinc-50 bg-zinc-900 border-zinc-900 hover:bg-black"
								}`}
							>
								Launch App
							</Link>
						</div>
					</div>

					{/* Main Content */}
					<div className="px-4 md:px-8 pb-16 max-w-6xl w-full space-y-6">
						{/* What is Wayfinder */}
						<section id="overview" className="scroll-mt-24">
							<button
								onClick={() => toggleSection("overview")}
								className={`w-full text-left flex items-center justify-between py-3 border-b transition-colors ${
									isDarkMode
										? "border-zinc-800 hover:border-zinc-600"
										: "border-zinc-300 hover:border-zinc-400"
								}`}
							>
								<h2
									className={`text-lg md:text-xl font-bold ${
										isDarkMode ? "text-zinc-100" : "text-zinc-900"
									}`}
								>
									What is Wayfinder?
								</h2>
								<span
									className={`text-base md:text-lg ${
										isDarkMode ? "text-zinc-400" : "text-zinc-600"
									}`}
								>
									{openSections.overview ? "−" : "+"}
								</span>
							</button>
							{openSections.overview && (
								<div className="py-4 space-y-4">
									<p
										className={`text-sm md:text-base ${
											isDarkMode ? "text-zinc-300" : "text-zinc-600"
										}`}
									>
										Wayfinder is a storage and management layer for NFT files.
										It keeps multiple links to the same artwork, tracks
										permissions, and renders metadata.
									</p>
									<div className="grid md:grid-cols-3 gap-4">
										<div
											className={`p-4 space-y-2 border ${
												isDarkMode
													? "bg-zinc-900 border-zinc-800"
													: "bg-white border-zinc-300"
											}`}
										>
											<h3
												className={`text-sm md:text-base font-medium ${
													isDarkMode ? "text-zinc-200" : "text-zinc-900"
												}`}
											>
												Multi-URI Storage
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-400" : "text-zinc-600"
												}`}
											>
												Keep backup links to the same file across IPFS, Arweave,
												or web servers.
											</p>
										</div>
										<div
											className={`p-4 space-y-2 border ${
												isDarkMode
													? "bg-zinc-900 border-zinc-800"
													: "bg-white border-zinc-300"
											}`}
										>
											<h3
												className={`text-sm md:text-base font-medium ${
													isDarkMode ? "text-zinc-200" : "text-zinc-900"
												}`}
											>
												Manifold Interface
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-400" : "text-zinc-600"
												}`}
											>
												This site connects Wayfinder storage with Manifold
												creator contracts for minting.
											</p>
										</div>
										<div
											className={`p-4 space-y-2 border ${
												isDarkMode
													? "bg-zinc-900 border-zinc-800"
													: "bg-white border-zinc-300"
											}`}
										>
											<h3
												className={`text-sm md:text-base font-medium ${
													isDarkMode ? "text-zinc-200" : "text-zinc-900"
												}`}
											>
												Permissions
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-400" : "text-zinc-600"
												}`}
											>
												Artists and collectors can add links, choose which to
												display, and more.
											</p>
										</div>
									</div>
								</div>
							)}
						</section>

						{/* Problem section condensed into Overview */}

						{/* How It Works */}
						<section id="how-uris" className="scroll-mt-24">
							<button
								onClick={() => toggleSection("uris")}
								className={`w-full text-left flex items-center justify-between py-3 border-b transition-colors ${
									isDarkMode
										? "border-zinc-800 hover:border-zinc-600"
										: "border-zinc-300 hover:border-zinc-400"
								}`}
							>
								<h2
									className={`text-lg md:text-xl font-bold ${
										isDarkMode ? "text-zinc-100" : "text-zinc-900"
									}`}
								>
									How Multiple URIs Work
								</h2>
								<span
									className={`text-base md:text-lg ${
										isDarkMode ? "text-zinc-400" : "text-zinc-600"
									}`}
								>
									{openSections.uris ? "−" : "+"}
								</span>
							</button>
							{openSections.uris && (
								<div className="py-4 space-y-4">
									<div
										className={`text-sm md:text-base space-y-4 ${
											isDarkMode ? "text-zinc-300" : "text-zinc-600"
										}`}
									>
										<p>
											Each token stores an array of URIs pointing to the same
											artwork hosted on different platforms (IPFS, Arweave,
											centralized servers, etc.).
										</p>
										<div className="grid md:grid-cols-3 gap-4">
											<div
												className={`p-4 border space-y-2 ${
													isDarkMode
														? "bg-zinc-900 border-zinc-800"
														: "bg-zinc-50 border-zinc-300"
												}`}
											>
												<h3
													className={`text-sm md:text-base font-medium ${
														isDarkMode ? "text-zinc-200" : "text-zinc-900"
													}`}
												>
													Artists
												</h3>
												<ul
													className={`space-y-1 text-xs md:text-sm ${
														isDarkMode ? "text-zinc-300" : "text-zinc-600"
													}`}
												>
													<li>• Add initial URIs</li>
													<li>• Choose which URI displays</li>
												</ul>
											</div>
											<div
												className={`p-4 border space-y-2 ${
													isDarkMode
														? "bg-zinc-900 border-zinc-800"
														: "bg-zinc-50 border-zinc-300"
												}`}
											>
												<h3
													className={`text-sm md:text-base font-medium ${
														isDarkMode ? "text-zinc-200" : "text-zinc-900"
													}`}
												>
													Collectors
												</h3>
												<ul
													className={`space-y-1 text-xs md:text-sm ${
														isDarkMode ? "text-zinc-300" : "text-zinc-600"
													}`}
												>
													<li>• Contribute backup links (if permitted)</li>
												</ul>
											</div>
											<div
												className={`p-4 border space-y-2 ${
													isDarkMode
														? "bg-zinc-900 border-zinc-800"
														: "bg-zinc-50 border-zinc-300"
												}`}
											>
												<h3
													className={`text-sm md:text-base font-medium ${
														isDarkMode ? "text-zinc-200" : "text-zinc-900"
													}`}
												>
													System
												</h3>
												<ul
													className={`space-y-1 text-xs md:text-sm ${
														isDarkMode ? "text-zinc-300" : "text-zinc-600"
													}`}
												>
													<li>• Auto-resolves first working URL (HTML mode)</li>
													<li>• Priority: artist URIs then collector URIs</li>
													<li>• Fallback if a link fails</li>
												</ul>
											</div>
										</div>
									</div>
								</div>
							)}
						</section>

						{/* Architecture */}
						<section id="how-it-works" className="scroll-mt-24">
							<button
								onClick={() => toggleSection("architecture")}
								className={`w-full text-left flex items-center justify-between py-3 border-b transition-colors ${
									isDarkMode
										? "border-zinc-800 hover:border-zinc-600"
										: "border-zinc-300 hover:border-zinc-400"
								}`}
							>
								<h2
									className={`text-lg md:text-xl font-bold ${
										isDarkMode ? "text-zinc-100" : "text-zinc-900"
									}`}
								>
									How It Works
								</h2>
								<span
									className={`text-base md:text-lg ${
										isDarkMode ? "text-zinc-400" : "text-zinc-600"
									}`}
								>
									{openSections.architecture ? "−" : "+"}
								</span>
							</button>
							{openSections.architecture && (
								<div className="py-4 space-y-4">
									<div className="grid md:grid-cols-2 gap-4">
										<div
											className={`p-4 space-y-2 ${
												isDarkMode ? "bg-zinc-900" : "bg-white"
											}`}
										>
											<h3
												className={`text-sm md:text-base font-medium ${
													isDarkMode ? "text-zinc-200" : "text-zinc-900"
												}`}
											>
												Wayfinder Core Contract
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-400" : "text-zinc-600"
												}`}
											>
												Stores URIs, metadata, permissions, and HTML templates.
												Renders metadata from stored state.
											</p>
										</div>
										<div
											className={`p-4 space-y-2 ${
												isDarkMode ? "bg-zinc-900" : "bg-white"
											}`}
										>
											<h3
												className={`text-sm md:text-base font-medium ${
													isDarkMode ? "text-zinc-200" : "text-zinc-900"
												}`}
											>
												Manifold Extension
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-400" : "text-zinc-600"
												}`}
											>
												Mints on Manifold creator contracts and initializes
												token data in Wayfinder.
											</p>
										</div>
									</div>
									<div
										className={`text-sm md:text-base space-y-4 ${
											isDarkMode ? "text-zinc-300" : "text-zinc-600"
										}`}
									>
										<p>
											Display modes: Direct file (image/animation_url) or Smart
											HTML template with variables like{" "}
											<code
												className={`px-1 text-xs ${
													isDarkMode ? "bg-zinc-800" : "bg-zinc-200"
												}`}
											>
												{"{{FILE_URIS}}"}
											</code>{" "}
											and{" "}
											<code
												className={`px-1 text-xs ${
													isDarkMode ? "bg-zinc-800" : "bg-zinc-200"
												}`}
											>
												{"{{FILE_HASH}}"}
											</code>
											.
										</p>
									</div>
								</div>
							)}
						</section>

						{/* Smart HTML details integrated into Architecture section */}

						{/* Features summarized elsewhere */}

						{/* Permissions System */}
						<section id="permissions" className="scroll-mt-24">
							<button
								onClick={() => toggleSection("permissions")}
								className={`w-full text-left flex items-center justify-between py-3 border-b transition-colors ${
									isDarkMode
										? "border-zinc-800 hover:border-zinc-600"
										: "border-zinc-300 hover:border-zinc-400"
								}`}
							>
								<h2
									className={`text-lg md:text-xl font-bold ${
										isDarkMode ? "text-zinc-100" : "text-zinc-900"
									}`}
								>
									Permissions
								</h2>
								<span
									className={`text-base md:text-lg ${
										isDarkMode ? "text-zinc-400" : "text-zinc-600"
									}`}
								>
									{openSections.permissions ? "−" : "+"}
								</span>
							</button>
							{openSections.permissions && (
								<div className="py-4 space-y-4">
									<div className="grid md:grid-cols-2 gap-4">
										<div
											className={`p-4 border space-y-2 ${
												isDarkMode
													? "bg-zinc-900 border-zinc-800"
													: "bg-zinc-50 border-zinc-300"
											}`}
										>
											<h3
												className={`text-sm md:text-base font-medium ${
													isDarkMode ? "text-zinc-200" : "text-zinc-900"
												}`}
											>
												Artist
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-300" : "text-zinc-600"
												}`}
											>
												Configure metadata, thumbnails, display mode, templates,
												and manage/add/remove URIs. May revoke own permissions
												at any time.
											</p>
										</div>
										<div
											className={`p-4 border space-y-2 ${
												isDarkMode
													? "bg-zinc-900 border-zinc-800"
													: "bg-zinc-50 border-zinc-300"
											}`}
										>
											<h3
												className={`text-sm md:text-base font-medium ${
													isDarkMode ? "text-zinc-200" : "text-zinc-900"
												}`}
											>
												Collector
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-300" : "text-zinc-600"
												}`}
											>
												May add URIs, choose displayed URI or thumbnail, and
												change display mode when enabled by the artist.
											</p>
										</div>
									</div>
								</div>
							)}
						</section>

						{/* Use cases removed to keep focus on protocol behavior */}

						{/* Quick Start and FAQ removed to stay concise */}
					</div>
				</div>
			</div>

			<Footer isDarkMode={isDarkMode} />
		</div>
	);
}

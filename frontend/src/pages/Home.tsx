import { Link } from "react-router-dom";
import { useState } from "react";
import Header from "../components/Header";
import { useTheme } from "../hooks/useTheme";
import Footer from "../components/Footer";

export default function Home() {
	const [openSections, setOpenSections] = useState<Record<string, boolean>>({
		why: true,
		overview: true,
		uris: false,
		lifecycle: true,
		roles: false,
		display: false,
		resilience: false,
		thumbnails: false,
		integration: false,
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
								Mint sturdier NFTs with on-chain multi-URI media storage system
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
										Wayfinder is a new way of storing media pointers on-chain.
										Store your art in multiple places instead of one to ensure
										durability. Wayfinder helps you accomplish this.
									</p>
									<div className="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
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
												On-Chain Metadata
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-400" : "text-zinc-600"
												}`}
											>
												Store your NFT metadata directly on-chain for maximum
												reliability and permanence.
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
												Multi-URI Storage
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-400" : "text-zinc-600"
												}`}
											>
												Off-chain metadata and artwork with multiple backup
												pointers across different storage platforms.
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
												Collector Participation
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-400" : "text-zinc-600"
												}`}
											>
												Allow collectors to add new pointers to give your art
												more chances to stay alive forever.
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
												Smart HTML Interface
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-400" : "text-zinc-600"
												}`}
											>
												Automatically resolve the first available pointer to
												ensure seamless backup functionality.
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
												Extended Customizability
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-400" : "text-zinc-600"
												}`}
											>
												Flexible configuration options for metadata, display
												modes, and URI management.
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
												Easy User Experience
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-400" : "text-zinc-600"
												}`}
											>
												Intuitive interface designed for both artists and
												collectors to manage their NFTs effortlessly.
											</p>
										</div>
									</div>
								</div>
							)}
						</section>
						{/* Why Wayfinder Matters */}
						<section id="why" className="scroll-mt-24">
							<button
								onClick={() => toggleSection("why")}
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
									Why Wayfinder Matters
								</h2>
								<span
									className={`text-base md:text-lg ${
										isDarkMode ? "text-zinc-400" : "text-zinc-600"
									}`}
								>
									{openSections.why ? "−" : "+"}
								</span>
							</button>
							{openSections.why && (
								<div className="py-4 space-y-4">
									<p
										className={`text-sm md:text-base ${
											isDarkMode ? "text-zinc-300" : "text-zinc-600"
										}`}
									>
										Visual NFT artworks often rely on external links. If a
										gateway, server, or API changes, the piece can break.
										Wayfinder stores the essential metadata and the artwork's
										content hash on-chain, while distributing the media itself
										across multiple networks. This way, the work's chance to
										remain verifiable and accessible increases.
									</p>
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
									How It Works
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

						{/* Display Modes */}
						<section id="display" className="scroll-mt-24">
							<button
								onClick={() => toggleSection("display")}
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
									Display Modes
								</h2>
								<span
									className={`text-base md:text-lg ${
										isDarkMode ? "text-zinc-400" : "text-zinc-600"
									}`}
								>
									{openSections.display ? "−" : "+"}
								</span>
							</button>
							{openSections.display && (
								<div className="py-4 space-y-4">
									<div className="grid md:grid-cols-2 gap-4">
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
												Direct File
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-400" : "text-zinc-600"
												}`}
											>
												Uses a selected artwork URI directly as the NFT's media.
												If the selected URI fails, artists or collectors must
												manually switch to an alternative URI. This mode has
												broader platform compatibility.
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
												HTML
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-400" : "text-zinc-600"
												}`}
											>
												Embeds an HTML template that automatically resolves the
												first available URI from all stored options
												(prioritizing artist URIs, then collector URIs).
												Provides maximum resilience but has limited wallet and
												platform support.
											</p>
										</div>
									</div>
								</div>
							)}
						</section>

						{/* Thumbnails */}
						<section id="thumbnails" className="scroll-mt-24">
							<button
								onClick={() => toggleSection("thumbnails")}
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
									Thumbnails
								</h2>
								<span
									className={`text-base md:text-lg ${
										isDarkMode ? "text-zinc-400" : "text-zinc-600"
									}`}
								>
									{openSections.thumbnails ? "−" : "+"}
								</span>
							</button>
							{openSections.thumbnails && (
								<div className="py-4 space-y-4">
									<div className="grid md:grid-cols-2 gap-4">
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
												On-chain
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-400" : "text-zinc-600"
												}`}
											>
												Store thumbnail image on-chain for even stronger
												durability.
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
												Off-chain
											</h3>
											<p
												className={`text-xs md:text-sm ${
													isDarkMode ? "text-zinc-400" : "text-zinc-600"
												}`}
											>
												Reference multiple thumbnail URIs and select which one
												to display.
											</p>
										</div>
									</div>
								</div>
							)}
						</section>
					</div>
				</div>
			</div>

			<Footer isDarkMode={isDarkMode} />
		</div>
	);
}

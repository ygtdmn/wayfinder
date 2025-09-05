import { Link } from "react-router-dom";
import ConnectButtonHeader from "./ConnectButtonHeader";

interface HeaderProps {
	isDarkMode: boolean;
	toggleTheme: () => void;
	hideConnectButton?: boolean;
}

export default function Header({ isDarkMode, toggleTheme, hideConnectButton }: HeaderProps) {
	return (
		<nav
			className={`sticky top-0 z-40 px-4 md:px-8 py-4 border-b ${
				isDarkMode
					? "border-zinc-800 bg-zinc-950"
					: "border-zinc-300 bg-zinc-50"
			}`}
		>
			<div className="max-w-6xl mx-auto flex items-center justify-between">
				<Link
					to="/"
					className={`font-bold tracking-tight ${
						isDarkMode ? "text-zinc-100" : "text-zinc-900"
					}`}
				>
					Wayfinder
				</Link>
				<div className="flex items-center gap-4">
					<button
						onClick={toggleTheme}
						className={`px-3 py-1 text-xs border rounded transition-colors ${
							isDarkMode
								? "border-zinc-600 text-zinc-400 hover:text-zinc-100 hover:border-zinc-400"
								: "border-zinc-300 text-zinc-600 hover:text-zinc-900 hover:border-zinc-600"
						}`}
					>
						{isDarkMode ? "Light" : "Dark"}
					</button>
					{!hideConnectButton && <ConnectButtonHeader isDarkMode={isDarkMode} />}
				</div>
			</div>
		</nav>
	);
}

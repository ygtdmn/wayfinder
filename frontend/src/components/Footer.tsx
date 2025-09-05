interface FooterProps {
	isDarkMode: boolean;
}

export default function Footer({ isDarkMode }: FooterProps) {
	return (
		<footer
			className={`px-4 md:px-8 py-6 md:py-8 border-t ${
				isDarkMode
					? "border-zinc-800 bg-zinc-950"
					: "border-zinc-300 bg-zinc-50"
			}`}
		>
			<div className="max-w-6xl mx-auto">
				<div className="flex items-center justify-between">
					<p
						className={`text-xs md:text-sm ${
							isDarkMode ? "text-zinc-400" : "text-zinc-600"
						}`}
					>
						Wayfinder is created by{" "}
						<a
							href="https://x.com/yigitduman"
							target="_blank"
							rel="noopener noreferrer"
							className={
								isDarkMode
									? "text-zinc-200 underline hover:text-zinc-100"
									: "text-zinc-800 underline hover:text-zinc-900"
							}
						>
							Yigit Duman
						</a>{" "}
						and released under the{" "}
						<span className={isDarkMode ? "text-zinc-200" : "text-zinc-800"}>
							<a
								href="https://github.com/ygtdmn/multiplex/blob/main/LICENSE.md"
								target="_blank"
								rel="noopener noreferrer"
								className={
									isDarkMode
										? "text-zinc-200 underline hover:text-zinc-100"
										: "text-zinc-800 underline hover:text-zinc-900"
								}
							>
								MIT License
							</a>
						</span>
						.
					</p>
					<div className="flex items-center gap-4">
						<a
							href="https://github.com/ygtdmn/multiplex"
							target="_blank"
							rel="noopener noreferrer"
							className={
								isDarkMode
									? "text-zinc-200 underline hover:text-zinc-100"
									: "text-zinc-800 underline hover:text-zinc-900"
							}
						>
							GitHub
						</a>
					</div>
				</div>
			</div>
		</footer>
	);
}

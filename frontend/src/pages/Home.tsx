import { Link } from "react-router-dom";

export default function Home() {
	return (
		<div className="min-h-screen flex items-center">
			<div className="px-8 space-y-12">
				<h1 className="text-8xl font-display font-black text-zinc-100 tracking-tight">
					multiplex
				</h1>

				<p className="text-2xl font-bold text-zinc-300">
					mint your off-chain art, as on-chain as it can be.
				</p>

				<Link
					to="/collections"
					className="inline-block text-xl font-black bg-white text-black px-8 py-4 hover:bg-gray-100 transition-all uppercase tracking-wide"
				>
					start creating
				</Link>
			</div>
		</div>
	);
}

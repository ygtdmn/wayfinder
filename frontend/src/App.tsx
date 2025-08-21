import { BrowserRouter as Router, Routes, Route } from "react-router-dom";
import Home from "./pages/Home";
import Collections from "./pages/Collections";
import Mint from "./pages/Mint";
import Update from "./pages/Update";
import CollectorZone from "./pages/CollectorZone";
import "./App.css";

function App() {
	return (
		<Router>
			<div className="min-h-screen bg-zinc-950">
				<Routes>
					<Route path="/" element={<Home />} />
					<Route path="/collections" element={<Collections />} />
					<Route path="/mint" element={<Mint />} />
					<Route path="/update" element={<Update />} />
					<Route path="/collector-zone" element={<CollectorZone />} />
				</Routes>
			</div>
		</Router>
	);
}

export default App;

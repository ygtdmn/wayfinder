import { useState } from "react";
import { BrowserRouter as Router, Routes, Route } from "react-router-dom";
import Home from "./pages/Home";
import Collections from "./pages/Collections";
import Mint from "./pages/Mint";
import Update from "./pages/Update";
import CollectorZone from "./pages/CollectorZone";
import { ThemeProvider } from "./contexts/ThemeProvider";
import "./App.css";

function App() {
	const [isDarkMode, setIsDarkMode] = useState(true);

	const toggleTheme = () => {
		setIsDarkMode(!isDarkMode);
	};

	return (
		<ThemeProvider isDarkMode={isDarkMode} toggleTheme={toggleTheme}>
			<Router>
				<Routes>
					<Route path="/" element={<Home />} />
					<Route path="/collections" element={<Collections />} />
					<Route path="/mint" element={<Mint />} />
					<Route path="/update" element={<Update />} />
					<Route path="/collector-zone" element={<CollectorZone />} />
				</Routes>
			</Router>
		</ThemeProvider>
	);
}

export default App;

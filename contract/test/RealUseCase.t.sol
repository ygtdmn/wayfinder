// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

import "forge-std/src/Test.sol";
import { IERC1155CreatorCore } from "@manifoldxyz/creator-core-solidity/contracts/core/IERC1155CreatorCore.sol";
import { console2 } from "forge-std/src/console2.sol";
import { MultiplexManifoldExtension } from "src/MultiplexManifoldExtension.sol";
import { Multiplex } from "src/Multiplex.sol";
import { IERC1155MetadataURI } from "@openzeppelin/contracts/interfaces/IERC1155MetadataURI.sol";

contract RealUseCaseTest is Test {
    function testFork_Example() external {
        // Silently pass this test if there is no API key.
        string memory alchemyApiKey = vm.envOr("API_KEY_ALCHEMY", string(""));
        if (bytes(alchemyApiKey).length == 0) {
            return;
        }

        // Otherwise, run the test against the mainnet fork.
        vm.createSelectFork({ urlOrAlias: "mainnet" });
        vm.startPrank(
            address(0x28996f7DECe7E058EBfC56dFa9371825fBfa515A), address(0x28996f7DECe7E058EBfC56dFa9371825fBfa515A)
        );
        string memory htmlTemplate =
            "<!DOCTYPE html><html><head><meta charset='utf-8'><title>{{ARTWORK_NAME}}</title></head><body style='margin:0;padding:0;display:flex;justify-content:center;align-items:center;min-height:100vh;background:#000;'><div style='color:white;'id='content'>Loading...</div><div id='debug' style='position:fixed;top:10px;left:10px;color:white;font-family:monospace;font-size:12px;max-width:300px;word-break:break-all;'></div><script>async function sha256(buffer) {const data = new Uint8Array(buffer);const totalBlocks = Math.ceil((data.length + 9) / 64);let processedBlocks = 0;function rightRotate(value, amount) { return (value >>> amount) | (value << (32 - amount)); }const k = [0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2];let h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];const len = data.length * 8;const padding = new Uint8Array(64 - ((data.length + 9) % 64));const padded = new Uint8Array(data.length + 1 + padding.length + 8);padded.set(data); padded[data.length] = 0x80;const view = new DataView(padded.buffer);view.setUint32(padded.length - 4, len, false);for (let i = 0; i < padded.length; i += 64) {processedBlocks++;if (processedBlocks % 4096 === 0) {const progress = Math.floor((processedBlocks / totalBlocks) * 100);debug.innerHTML = debug.innerHTML.split('<br>Hashing:')[0] + '<br>Hashing: ' + progress + '%';await new Promise(resolve => setTimeout(resolve, 0));}const w = new Array(64);for (let j = 0; j < 16; j++) w[j] = view.getUint32(i + j * 4, false);for (let j = 16; j < 64; j++) {const s0 = rightRotate(w[j-15], 7) ^ rightRotate(w[j-15], 18) ^ (w[j-15] >>> 3);const s1 = rightRotate(w[j-2], 17) ^ rightRotate(w[j-2], 19) ^ (w[j-2] >>> 10);w[j] = (w[j-16] + s0 + w[j-7] + s1) >>> 0;}let [a,b,c,d,e,f,g,h0] = h;for (let j = 0; j < 64; j++) {const S1 = rightRotate(e, 6) ^ rightRotate(e, 11) ^ rightRotate(e, 25);const ch = (e & f) ^ (~e & g);const temp1 = (h0 + S1 + ch + k[j] + w[j]) >>> 0;const S0 = rightRotate(a, 2) ^ rightRotate(a, 13) ^ rightRotate(a, 22);const maj = (a & b) ^ (a & c) ^ (b & c);const temp2 = (S0 + maj) >>> 0;h0 = g; g = f; f = e; e = (d + temp1) >>> 0; d = c; c = b; b = a; a = (temp1 + temp2) >>> 0;}h = h.map((x, i) => (x + [a,b,c,d,e,f,g,h0][i]) >>> 0);}return h.map(x => x.toString(16).padStart(8, '0')).join('');}const imageUris = [{{FILE_URIS}}];const expectedHash = '{{FILE_HASH}}';const debug = document.getElementById('debug');debug.innerHTML = 'Expected: ' + expectedHash + '<br>URIs: ' + imageUris.length + '<br>Checking available images...';async function calculateHash(arrayBuffer) {try {return await sha256(arrayBuffer);} catch (e) {debug.innerHTML += '<br>Hash error: ' + e.message;return null;}}async function loadImage() {const content = document.getElementById('content');for (let i = 0; i < imageUris.length; i++) {const uri = imageUris[i];try {debug.innerHTML += '<br>Trying: ' + uri.substring(0, 30) + '...';const response = await fetch(uri, { mode: 'cors' });debug.innerHTML += '<br>Status: ' + response.status;if (response.status === 200) {const arrayBuffer = await response.arrayBuffer();debug.innerHTML += '<br>Size: ' + arrayBuffer.byteLength;if (!expectedHash || expectedHash.length === 0) {debug.innerHTML += '<br>NO EXPECTED HASH - Cannot verify';continue;}const fileSizeMB = (arrayBuffer.byteLength / (1024 * 1024)).toFixed(1);debug.innerHTML += '<br>Hashing ' + fileSizeMB + 'MB file...';const hashHex = await calculateHash(arrayBuffer);if (!hashHex) {debug.innerHTML += '<br>Hash calculation failed';continue;}debug.innerHTML += '<br>Hash: ' + hashHex.substring(0, 16) + '...';const cleanExpected = expectedHash.replace('0x', '');if (hashHex === cleanExpected) {debug.innerHTML += '<br>HASH MATCH! Loading...';const stage = document.createElement('div');stage.style.position = 'fixed';stage.style.inset = '0';stage.style.overflow = 'hidden';stage.style.background = '#000';stage.style.touchAction = 'none';stage.style.cursor = 'grab';const panzoom = document.createElement('div');panzoom.style.transformOrigin = '0 0';panzoom.style.visibility = 'hidden';const img = document.createElement('img');img.src = uri;img.style.display = 'block';img.style.userSelect = 'none';img.draggable = false;let scale = 1, minScale = 1, x = 0, y = 0;const zoomFactors = [1, 2, 3];let zoomIndex = 0;function clampPosition() {const sw = stage.clientWidth, sh = stage.clientHeight;const iw = img.naturalWidth || 0, ih = img.naturalHeight || 0;const dw = iw * scale, dh = ih * scale;if (dw <= sw) { x = Math.round((sw - dw) / 2); } else { if (x > 0) x = 0; if (x < sw - dw) x = Math.round(sw - dw); }if (dh <= sh) { y = Math.round((sh - dh) / 2); } else { if (y > 0) y = 0; if (y < sh - dh) y = Math.round(sh - dh); }}function applyTransform() {clampPosition();panzoom.style.transform = 'translate(' + x + 'px,' + y + 'px) scale(' + scale + ')';}function setZoomAt(factor, cx, cy) {const newScale = Math.max(minScale, Math.min(10, minScale * factor));const k = newScale / scale;x = cx - (cx - x) * k;y = cy - (cy - y) * k;scale = newScale;applyTransform();}img.onload = () => {const sw = stage.clientWidth, sh = stage.clientHeight;const iw = img.naturalWidth, ih = img.naturalHeight;minScale = Math.min(sw / iw, sh / ih);scale = minScale;x = Math.round((sw - iw * scale) / 2);y = Math.round((sh - ih * scale) / 2);applyTransform();panzoom.style.visibility = 'visible';debug.style.display = 'none';};let isPanning = false, startX = 0, startY = 0, startTX = 0, startTY = 0, moved = false;stage.addEventListener('pointerdown', (e) => {isPanning = true;moved = false;startX = e.clientX; startY = e.clientY;startTX = x; startTY = y;stage.setPointerCapture(e.pointerId);stage.style.cursor = 'grabbing';});stage.addEventListener('pointermove', (e) => {if (!isPanning) return;const dx = e.clientX - startX;const dy = e.clientY - startY;if (Math.abs(dx) > 2 || Math.abs(dy) > 2) moved = true;x = startTX + dx;y = startTY + dy;applyTransform();});const endPan = (e) => {if (!isPanning) return;isPanning = false;stage.releasePointerCapture(e.pointerId);stage.style.cursor = 'grab';};stage.addEventListener('pointerup', (e) => {const rect = stage.getBoundingClientRect();const cx = e.clientX - rect.left;const cy = e.clientY - rect.top;const wasMoved = moved;endPan(e);if (!wasMoved) {zoomIndex = (zoomIndex + 1) % zoomFactors.length;setZoomAt(zoomFactors[zoomIndex], cx, cy);}});stage.addEventListener('pointercancel', endPan);stage.addEventListener('wheel', (e) => {e.preventDefault();const rect = stage.getBoundingClientRect();const cx = e.clientX - rect.left;const cy = e.clientY - rect.top;const zoom = Math.exp(-e.deltaY * 0.0015);const newScale = Math.max(minScale, Math.min(10, scale * zoom));const k = newScale / scale;x = cx - (cx - x) * k;y = cy - (cy - y) * k;scale = newScale;applyTransform();}, { passive: false });window.addEventListener('resize', () => {const sw = stage.clientWidth, sh = stage.clientHeight;const iw = img.naturalWidth, ih = img.naturalHeight;const newMin = Math.min(sw / iw, sh / ih);minScale = newMin;if (scale < minScale) {scale = minScale;}applyTransform();});content.innerHTML = '';content.appendChild(stage);stage.appendChild(panzoom);panzoom.appendChild(img);return;} else {debug.innerHTML += '<br>Hash mismatch';}}} catch (e) { debug.innerHTML += '<br>Error: ' + e.message; }}content.innerHTML = 'No image with matching hash found. All images failed hash verification.';}loadImage();</script></body></html>";
        string memory metadata =
            unicode"\"name\": \"Off-Chain Art\",\"description\": \"An artwork that blends six historic paintings which were altered without the artists' intent: The Night Watch by Rembrandt, The Last Supper by Leonardo da Vinci, The Vision of Saint John by El Greco, The Last Judgement by Michelangelo, Las Meninas by Diego Velázquez, and The Death of Actaeon by Titian.\",\"attributes\": [{\"trait_type\": \"Artwork 1\", \"value\": \"The Night Watch by Rembrandt\"}, {\"trait_type\": \"Artwork 2\", \"value\": \"The Last Supper by Leonardo da Vinci\"}, {\"trait_type\": \"Artwork 3\", \"value\": \"The Vision of Saint John by El Greco\"}, {\"trait_type\": \"Artwork 4\", \"value\": \"The Last Judgement by Michelangelo\"}, {\"trait_type\": \"Artwork 5\", \"value\": \"Las Meninas by Diego Velázquez\"}, {\"trait_type\": \"Artwork 6\", \"value\": \"The Death of Actaeon by Titian\"}]";

        Multiplex multiplex = new Multiplex(htmlTemplate);
        MultiplexManifoldExtension extension = new MultiplexManifoldExtension(address(multiplex));

        IERC1155CreatorCore ephemera = IERC1155CreatorCore(address(0xCb337152b6181683010D07e3f00e7508cd348BC7));
        ephemera.registerExtension(address(extension), "");
        address[] memory recipients = new address[](1);
        recipients[0] = address(0x6);
        uint256[] memory quantities = new uint256[](1);
        quantities[0] = 11;

        Multiplex.Artwork memory artwork = Multiplex.Artwork({
            artistUris: new string[](5),
            collectorUris: new string[](0),
            mimeType: "image/png",
            fileHash: "0x1234567890abcdef",
            isAnimationUri: false,
            selectedArtistUriIndex: 0
        });

        artwork.artistUris[0] = "https://ipfs.io/ipfs/1";
        artwork.artistUris[1] = "https://ipfs.io/ipfs/2";
        artwork.artistUris[2] = "https://ipfs.io/ipfs/3";
        artwork.artistUris[3] = "https://ipfs.io/ipfs/4";
        artwork.artistUris[4] = "https://ipfs.io/ipfs/5";
        artwork.selectedArtistUriIndex = 0;

        Multiplex.Thumbnail memory thumbnail = Multiplex.Thumbnail({
            kind: Multiplex.ThumbnailKind.OFF_CHAIN,
            onChain: Multiplex.OnChainThumbnail({ mimeType: "", chunks: new address[](0), zipped: false }),
            offChain: Multiplex.OffChainThumbnail({ uris: new string[](5), selectedUriIndex: 0 })
        });

        thumbnail.offChain.uris[0] = "https://ipfs.io/ipfs/thumb1";
        thumbnail.offChain.uris[1] = "https://ipfs.io/ipfs/thumb2";
        thumbnail.offChain.uris[2] = "https://ipfs.io/ipfs/thumb3";
        thumbnail.offChain.uris[3] = "https://ipfs.io/ipfs/thumb4";
        thumbnail.offChain.uris[4] = "https://ipfs.io/ipfs/thumb5";
        thumbnail.offChain.selectedUriIndex = 2;

        Multiplex.DisplayMode displayMode = Multiplex.DisplayMode.HTML;
        Multiplex.Permissions memory permissions = Multiplex.Permissions({ flags: uint16(0xFFFF) });

        Multiplex.OwnershipConfig memory ownership =
            Multiplex.OwnershipConfig({ selector: 0x6352211e, style: Multiplex.OwnershipStyle.OWNER_OF });

        Multiplex.InitConfig memory config = Multiplex.InitConfig({
            metadata: metadata,
            artwork: artwork,
            thumbnail: thumbnail,
            displayMode: displayMode,
            permissions: permissions,
            ownership: ownership
        });

        bytes[] memory thumbnailChunks = new bytes[](0);

        extension.mintERC1155(address(ephemera), recipients, quantities, config, thumbnailChunks);

        console2.log(IERC1155MetadataURI(address(ephemera)).uri(8));

        vm.stopPrank();

        vm.prank(address(0x6));
        string[] memory newUris = new string[](1);
        newUris[0] = "https://ipfs.io/ipfs/test6";
        multiplex.addArtworkUris(address(ephemera), 8, newUris);

        string[] memory uris = multiplex.getArtistArtworkUris(address(ephemera), 8);
        for (uint256 i = 0; i < uris.length; i++) {
            console2.log(uris[i]);
        }
    }
}

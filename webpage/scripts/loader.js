function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

document.addEventListener("DOMContentLoaded", () => {
  const phrases = [
    "Finding diamonds...",
    "Building dirt houses...",
    "Getting wood...",
    "Breeding cows...",
    "Spawning villagers...",
    "Digging straight down (not recommended)...",
    "Crafting backup plans...",
    "Someone read this?",
    "Redstone engineers at work...",
    "Generating world...",
    "Loading BackupCraft..."
  ];

  const random = phrases[Math.floor(Math.random() * phrases.length)];
  document.getElementById("loader-text").textContent = random;
});

window.addEventListener("load", async () => {
  const loader = document.getElementById("loader");
  if (loader) {
    await sleep(700);
    loader.style.opacity = "0";
    setTimeout(() => loader.style.display = "none", 400);
  }
});


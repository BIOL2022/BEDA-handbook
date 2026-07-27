function startCountdown(targetDate, elementId) {
  const countdownElement = document.getElementById(elementId);
  if (!countdownElement) return;

  countdownElement.setAttribute("role", "timer");
  countdownElement.setAttribute("aria-live", "off");

  let interval;

  function updateCountdown() {
    const now = new Date().getTime();
    const distance = new Date(targetDate).getTime() - now;

    if (distance < 0) {
      if (interval) clearInterval(interval);
      countdownElement.textContent = "0d - time's up!";
      return;
    }

    const days = Math.floor(distance / (1000 * 60 * 60 * 24));
    const hours = Math.floor((distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60));
    const seconds = Math.floor((distance % (1000 * 60)) / 1000);

    countdownElement.textContent = `${days}d ${hours}h ${minutes}m ${seconds}s`;
  }

  updateCountdown();
  interval = setInterval(updateCountdown, 1000);
}

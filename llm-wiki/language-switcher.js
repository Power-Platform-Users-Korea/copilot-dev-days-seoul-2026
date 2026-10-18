(() => {
  const links = document.querySelectorAll('.language-switcher a');
  function updateLinks() {
    const chapter = document.querySelector('#trail a.now');
    const hash = chapter ? `#${chapter.dataset.id}` : location.hash;
    links.forEach(link => {
      const url = new URL(link.href);
      url.hash = hash;
      link.href = url.href;
    });
  }
  updateLinks();
  addEventListener('hashchange', updateLinks);
  const trail = document.querySelector('#trail');
  if (trail) {
    new MutationObserver(updateLinks).observe(trail, {
      subtree: true,
      attributes: true,
      attributeFilter: ['class']
    });
  }
})();

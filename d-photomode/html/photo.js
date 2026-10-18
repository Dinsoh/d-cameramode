/* Display only: inventory ownership and records must be resolved on the server. */
(() => {
  const element = id => document.getElementById(id);
  let current = null;
  let generation = 0;
  let closing = false;
  function close() {
    current = null; generation++;
    element('photoViewer').hidden = true;
    element('photoImage').removeAttribute('src');
    element('photoLink').value = '';
    element('photoCopyStatus').textContent = '';
    element('photoFallback').hidden = true;
  }
  window.addEventListener('message', ({ data }) => {
    if (data?.action === 'closePhoto') { close(); return; }
    if (data?.action !== 'photo') return;
    close();
    const photo = data.photo;
    if (!photo || typeof photo.url !== 'string' || typeof photo.id !== 'string') return;
    // Public HTTPS images only. Authoritative provider validation belongs on the server.
    let url;
    try { url = new URL(photo.url); } catch (_) { return; }
    if (url.protocol !== 'https:' || url.username || url.password) return;
    current = { id: photo.id, url: url.href, public: photo.public === true };
    element('photoCaption').textContent = [...String(photo.caption || '')].slice(0,120).join('');
    element('photoPhotographer').textContent = [...String(photo.photographer || '')].slice(0,100).join('');
    const date = new Date(photo.takenAt);
    element('photoDate').textContent = Number.isNaN(date.valueOf()) ? '' : date.toLocaleDateString(undefined,{year:'numeric',month:'short',day:'numeric'});
    element('photoDate').dateTime = Number.isNaN(date.valueOf()) ? '' : date.toISOString();
    element('photoFallback').hidden = true;
    element('photoLoadError').hidden = true;
    element('photoCopy').hidden = !current.public;
    element('photoPublicNotice').hidden = !current.public;
    element('photoImage').referrerPolicy = 'no-referrer';
    element('photoImage').src = current.url;
    element('photoViewer').hidden = false;
    element('photoClose').focus();
  });
  element('photoImage').addEventListener('error', () => {
    if (current) element('photoLoadError').hidden = false;
  });
  async function requestClose() {
    if (!current || closing) return;
    closing = true;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 2000);
    try {
      const response = await fetch(`https://${GetParentResourceName()}/closePhoto`, {
        method:'POST', headers:{'Content-Type':'application/json'}, body:'{}', signal:controller.signal
      });
      if (!response.ok) throw new Error('Close failed');
      close();
    } catch (_) { element('photoCopyStatus').textContent = 'Could not close. Press Escape to retry.'; }
    finally { clearTimeout(timeout); closing = false; }
  }
  for (const id of ['photoClose','photoDone']) element(id).addEventListener('click',requestClose);
  element('photoCopy').addEventListener('click', async () => {
    if (!current?.public) return;
    const snapshot = current, version = generation;
    try {
      if (!navigator.clipboard?.writeText) throw new Error('Clipboard unavailable');
      await navigator.clipboard.writeText(snapshot.url);
      if (version === generation) element('photoCopyStatus').textContent = 'Image link copied.';
    } catch (_) {
      if (version !== generation) return;
      element('photoCopyStatus').textContent = 'Clipboard unavailable. Select and copy the link below.';
      element('photoLink').value = snapshot.url;
      element('photoFallback').hidden = false;
      element('photoLink').focus(); element('photoLink').select();
    }
  });
  window.addEventListener('keydown', event => {
    if (current && event.key === 'Escape') { event.preventDefault(); requestClose(); }
  });
})();

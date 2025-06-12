function copyText(text) {
  navigator.clipboard.writeText(text).then(() => alert('계좌번호가 복사되었습니다.'));
}

const form = document.getElementById('guestbook-form');
const entries = document.querySelector('.guestbook-entries');

form.addEventListener('submit', (e) => {
  e.preventDefault();
  const name = form.querySelector('input').value;
  const message = form.querySelector('textarea').value;
  const entry = document.createElement('div');
  entry.className = 'entry';
  entry.innerHTML = `<strong>${name}</strong>: ${message}`;
  entries.prepend(entry);
  form.reset();
});

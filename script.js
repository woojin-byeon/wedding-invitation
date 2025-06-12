function copyText(text) {
  navigator.clipboard.writeText(text).then(() => alert('계좌번호가 복사되었습니다.'));
}

// Swiper 초기화
new Swiper('.swiper', {
  loop: true,
  pagination: {
    el: '.swiper-pagination',
  },
});

// 방명록 기능
const form = document.getElementById('guestbook-form');
const entries = document.querySelector('.guestbook-entries');

const storedEntries = JSON.parse(localStorage.getItem('guestbook') || "[]");
storedEntries.forEach(addEntryToDOM);

form.addEventListener('submit', (e) => {
  e.preventDefault();
  const name = form.querySelector('input').value;
  const message = form.querySelector('textarea').value;
  const entry = { name, message };
  storedEntries.unshift(entry);
  localStorage.setItem('guestbook', JSON.stringify(storedEntries));
  addEntryToDOM(entry);
  form.reset();
});

function addEntryToDOM(entry) {
  const div = document.createElement('div');
  div.className = 'entry';
  div.innerHTML = `<strong>${entry.name}</strong>: ${entry.message}`;
  entries.prepend(div);
}

function copyAccountNumber(id) {
  const accountNumber = document.getElementById(id).innerText;
  navigator.clipboard.writeText(accountNumber).then(() => {
    alert('계좌번호가 복사되었습니다.');
  });
}

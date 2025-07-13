  const form = document.getElementById('contact-form');

  form.addEventListener('submit', async (event) => {
    event.preventDefault();

    const data = {
      nome: form.name.value,
      email: form.email.value,
      mensagem: form.message.value,
    };

    try {
      const response = await fetch('/.netlify/functions/sendEmail', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      });

      const result = await response.json();
      alert(result.message || 'Message send!.');
      form.reset();
    } catch (err) {
      alert('Error. Message not send.');
      console.error(err);
    }
  });
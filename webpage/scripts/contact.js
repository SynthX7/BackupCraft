const form = document.getElementById("contact-form");

form.addEventListener("submit", async (event) => {
  event.preventDefault(); // evita o comportamento padrão de recarregar a página

  const data = {
    nome: form.name.value.trim(),
    email: form.email.value.trim(),
    mensagem: form.message.value.trim(),
  };

  try {
    const response = await fetch("/.netlify/functions/sendEmail", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data),
    });

    const result = await response.json();

    if (response.ok) {
      alert(result.message);
      form.reset();
    } else {
      alert(result.error || "Erro ao enviar a mensagem.");
    }
  } catch (error) {
    alert("Erro de conexão com o servidor.");
    console.error(error);
  }
});

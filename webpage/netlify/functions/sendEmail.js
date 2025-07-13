const nodemailer = require('nodemailer');

exports.handler = async function(event, context) {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  const data = JSON.parse(event.body);

  const { nome, email, mensagem } = data;

  if (!nome || !email || !mensagem) {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: 'Por favor, preencha todos os campos.' }),
    };
  }

  // Configurar transporte SMTP
  let transporter = nodemailer.createTransport({
    service: 'gmail', // ou outro serviço
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
  });

  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: process.env.EMAIL_USER,
    subject: `Contato do site: ${nome}`,
    text: `Nome: ${nome}\nEmail: ${email}\nMensagem:\n${mensagem}`,
  };

  try {
    await transporter.sendMail(mailOptions);
    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'Mensagem enviada com sucesso!' }),
    };
  } catch (error) {
    console.error(error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Erro ao enviar a mensagem.' }),
    };
  }
};

require('dotenv').config();
const express = require('express');
const nodemailer = require('nodemailer');
const cors = require('cors');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors()); // permite requisições do frontend
app.use(express.json()); // interpreta JSON no corpo da requisição

// Configurar o transporte SMTP
const transporter = nodemailer.createTransport({
  service: 'gmail', // ou outro serviço SMTP
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

// Rota para receber o formulário
app.post('/send', async (req, res) => {
  const { nome, email, mensagem } = req.body;

  if (!nome || !email || !mensagem) {
    return res.status(400).json({ error: 'Todos os campos são obrigatórios.' });
  }

  const mailOptions = {
    from: process.env.EMAIL_USER,
    to: process.env.EMAIL_USER, // pode ser outro e-mail que queira receber
    subject: `Nova mensagem do formulário de contato: ${nome}`,
    text: `
    Nome: ${nome}
    E-mail: ${email}
    Mensagem:
    ${mensagem}
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    res.status(200).json({ message: 'Mensagem enviada com sucesso.' });
  } catch (error) {
    console.error('Erro ao enviar e-mail:', error);
    res.status(500).json({ error: 'Erro ao enviar a mensagem.' });
  }
});

app.listen(port, () => {
  console.log(`Servidor rodando na porta ${port}`);
});

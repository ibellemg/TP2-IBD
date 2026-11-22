#!/bin/bash
# TP2 - Grupo 5 - Gera os dados, cria o banco, carrega e cria os gatilhos (Linux/macOS)
# Uso:  bash preparar_banco.sh
set -e
cd "$(dirname "$0")"

echo ">> Gerando os dados (uns 15 segundos)..."
rm -rf dados
python3 gerar_dados.py

read -s -p "Senha do MySQL (usuario root): " SENHA; echo
export MYSQL_PWD="$SENHA"

echo ">> Criando o banco e as tabelas..."
mysql -u root < 01_esquema.sql

echo ">> Carregando os CSVs (pode levar alguns minutos)..."
sed "s#/caminho/para/dados/#$(pwd)/dados/#g" 02_carregar_dados.sql \
  | mysql -u root --local-infile=1 --table

echo ">> Criando os gatilhos..."
mysql -u root < 04_gatilhos.sql

echo ">> Pronto! Banco tp2_plantoes criado, carregado e com os gatilhos."

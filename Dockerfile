FROM nginx:alpine
LABEL autor="Mateus Afonso Miranda de Oliveira - 20231003300546"
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY site/ /usr/share/nginx/html/
EXPOSE 80

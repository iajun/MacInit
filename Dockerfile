FROM ubuntu:mantic

ENV LV_BRANCH release-1.3/neovim-0.9

ARG GIT_USER_EMAIL=sharp.zhou@shopee.com
ARG GIT_USER_NAME=sharp.zhou

COPY src /tmp

# Set the working directory in the container
WORKDIR /tmp

# Update apt sources to use Aliyun mirrors
RUN sed -i s@/archive.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list \
&& sed -i s@/security.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list \
&& apt-get clean && apt-get update

# Install necessary base packages
RUN apt-get install curl git silversearcher-ag -y

# Install Python3 and Pip
RUN apt-get install python3 python3-pip -y

# Install Neovim
RUN curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage && \
    chmod u+x nvim.appimage && \
    ./nvim.appimage --appimage-extract && \
    mv squashfs-root / && \
    ln -s /squashfs-root/AppRun /usr/bin/nvim

# Install LunarVim
RUN no | bash -c "$(curl -fsSL https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.3/neovim-0.9/utils/installer/install.sh)" && \
    ln -s /root/.local/bin/lvim /usr/bin/v

# Install Zsh
RUN apt-get install zsh -y

# Install Oh My Zsh
RUN yes | bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Create zsh config directory and set up zinit
ENV ZDOTDIR /root/.config/zsh
RUN mkdir -p ~/.config/zsh && \
    rm ~/.zshrc && \
    mv ~/.oh-my-zsh $ZDOTDIR && \
    cp ./zsh/.zshrc $ZDOTDIR/.zshrc && \
    yes | bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"

# Set NVM environment variables and install NVM
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash \
    && echo 'export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"' >> $ZDOTDIR/.zshrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> $ZDOTDIR/.zshrc

# Activate nvm and install Node.js and Yarn
SHELL ["/bin/zsh", "-c"]
RUN source $ZDOTDIR/.zshrc && \
    nvm install 16 && \
    npm i -g yarn

# Remove unnecessary files
RUN rm -rf /tmp

# Set Git config
RUN git config --global user.email $GIT_USER_EMAIL
RUN git config --global user.name $GIT_USER_NAME

# Run the container command
CMD ["/bin/zsh"]

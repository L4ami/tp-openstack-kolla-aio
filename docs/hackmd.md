# TP – Construire son propre cloud OpenStack sur une seule machine (Kolla-Ansible All-in-One)

###### tags: `OpenStack` `Kolla-Ansible` `Virtualisation` `Cloud` `Ubuntu`

> **Auteur :** Lami · **Date :** 27 octobre 2026
> **En une phrase :** on a transformé une machine virtuelle Ubuntu en un **petit cloud privé**, comme un mini « Amazon Web Services » perso. On a ensuite créé dans ce cloud une petite machine virtuelle, joignable depuis Windows.

---

## 📌 Comment lire ce document

Ce compte-rendu est écrit pour **quelqu'un qui débute complètement**. Chaque mot technique est expliqué la première fois qu'il apparaît, et chaque commande est détaillée.

Tu vas croiser ces petits symboles :

| Symbole | Signification |
|---|---|
| 📖 **C'est quoi ?** | Définition d'un mot technique |
| 💡 **Pourquoi ?** | La raison de ce qu'on fait |
| 🧠 **À retenir** | Le résumé à connaître par cœur |
| ⚠️ **Attention** | Un piège à éviter |
| 🔒 **Secret** | Une information à ne jamais publier |
| 📸 **Capture** | La preuve en image |

**Où taper les commandes ?** On travaille avec **trois machines différentes**, alors chaque bloc de commandes indique où le taper :

| Repère | Machine | Comment la reconnaître |
|---|---|---|
| 🪟 **Windows** | Ton vrai PC | La ligne commence par `PS C:\Users\Lami>` |
| 🐧 **Ubuntu** | La VM qui porte OpenStack | La ligne commence par `lami@openstack-aio:~$` |
| 📦 **Cirros** | La petite VM créée **dans** OpenStack | La ligne commence par `$` |

---

## Sommaire

[TOC]

---

## 0. Le résultat final en un coup d'œil

![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/42-horizon-topologie-reseau.png)

Ce schéma est tiré d'Horizon, le site web d'OpenStack. On y lit, de gauche à droite :
- **public** (en bleu) : le réseau « extérieur », c'est-à-dire le réseau de VMware où se trouve aussi ton PC Windows ;
- **router1** : un routeur virtuel qui relie les deux réseaux ;
- **private** (en orange) : un réseau interne au cloud ;
- **vm-cirros** : la petite VM qu'on a créée dans le cloud.

À la fin du TP, depuis Windows, on a pu :
- ✅ **pinguer** cette VM ;
- ✅ s'y **connecter en SSH** ;
- ✅ vérifier que la VM accède à **Internet** ;
- ✅ la voir dans le **site web Horizon**.

---

## 1. Objectif du TP

Installer **OpenStack** (un logiciel qui sert à fabriquer un cloud) sur **une seule machine virtuelle**, grâce à un outil d'installation automatique appelé **Kolla-Ansible**. Ensuite, prouver que ça marche en créant une VM dans ce cloud.

---

## 2. Les bases à comprendre avant de commencer

### 2.1 Machine virtuelle et hyperviseur

:::info
📖 **C'est quoi une machine virtuelle (VM) ?**
C'est un **faux ordinateur**, simulé par un logiciel, qui tourne à l'intérieur d'un vrai ordinateur. Il a son propre processeur virtuel, sa propre mémoire, son propre disque et son propre système (Windows, Linux…). Pour lui, tout semble réel.
:::

:::info
📖 **C'est quoi un hyperviseur ?**
C'est le logiciel qui **fabrique et fait tourner** les VM. Il partage les vraies ressources du PC (processeur, mémoire, disque) entre plusieurs VM. Exemples : **VMware Workstation**, ESXi (vu au TP précédent), KVM, QEMU.
:::

> **Analogie :** un immeuble (le PC) découpé en appartements (les VM). L'hyperviseur, c'est le gérant de l'immeuble : il attribue à chaque appartement sa part d'électricité, d'eau et de place.

### 2.2 Le cloud et le IaaS

:::info
📖 **C'est quoi le cloud ?**
C'est le fait d'utiliser des ressources informatiques (serveurs, stockage, réseau) **à la demande**, en **libre-service**, sans s'occuper du matériel. On clique ou on tape une commande, et on reçoit une VM en quelques secondes.
:::

:::info
📖 **C'est quoi le IaaS ?**
*Infrastructure as a Service*, c'est-à-dire « l'infrastructure en tant que service ». Le cloud te fournit les briques de base : des **VM**, des **réseaux** et du **stockage**. C'est toi qui installes ce que tu veux dessus. AWS, Azure et Google Cloud font du IaaS. **OpenStack permet de faire la même chose chez soi.**
:::

### 2.3 OpenStack

:::info
📖 **C'est quoi OpenStack ?**
C'est un **logiciel libre et gratuit** qui transforme un ou plusieurs serveurs en **cloud privé IaaS**. Ce n'est pas un seul programme, mais un **ensemble de petits services**. Chacun a un nom et un rôle précis.
:::

:::success
💡 **Différence avec ESXi (TP précédent) :**
- **ESXi** est un **hyperviseur**. Il sait faire tourner des VM, et c'est un administrateur qui les crée une par une.
- **OpenStack** est une **couche au-dessus des hyperviseurs**. Il ajoute :
  - des utilisateurs et des projets ;
  - un catalogue d'images ;
  - des réseaux virtuels complets ;
  - une API ;
  - un site web en libre-service.
:::

> **Analogie de l'hôtel :** ESXi, c'est un bâtiment avec des chambres. OpenStack, c'est **tout l'hôtel** qui fonctionne autour : la réception, le système de réservation, les badges, le plan des chambres, le site web pour réserver…

**Les services OpenStack de ce TP (avec l'analogie de l'hôtel) :**

| Service | Son rôle, en simple | Dans l'hôtel, ce serait… |
|---|---|---|
| **Keystone** | Vérifie **qui tu es** (identifiant et mot de passe) et te donne un **jeton** (*token*), une sorte de badge temporaire. Il tient aussi la liste de tous les services. | La **réception** qui vérifie ta carte d'identité et te donne un badge |
| **Nova** | Crée, démarre, arrête et supprime les **VM** (appelées « instances » dans OpenStack) | Le **service qui prépare les chambres** |
| **Glance** | Stocke les **images** : les disques modèles à partir desquels on crée les VM | Le **catalogue des modèles de chambres** |
| **Neutron** | Gère tout le **réseau** : réseaux virtuels, adresses IP, routeurs, pare-feu | L'**électricien et le standard téléphonique** qui câblent les chambres |
| **Placement** | Tient l'inventaire des **ressources libres** (processeurs, mémoire, disque) | Le **tableau des chambres libres** |
| **Horizon** | Le **site web** pour tout gérer à la souris | Le **site internet de l'hôtel** |
| **Heat** | Crée plusieurs ressources d'un coup à partir d'un fichier modèle (*orchestration*) | Le **forfait « séminaire tout compris »** |

**Les services « de support », qui aident les autres :**

| Service | Rôle | Analogie |
|---|---|---|
| **MariaDB** | Base de données : chaque service y enregistre ses informations | Le **registre** de l'hôtel |
| **RabbitMQ** | File de messages : les services se parlent à travers lui | Le **talkie-walkie** du personnel |
| **Memcached** | Cache, c'est-à-dire une mémoire rapide (garde les jetons pour aller plus vite) | Le **pense-bête** du réceptionniste |
| **HAProxy** | Répartiteur : reçoit toutes les demandes sur une seule adresse et les envoie au bon service | Le **standard téléphonique** avec un seul numéro |
| **Open vSwitch** | Un **switch réseau virtuel** (logiciel) utilisé par Neutron | Les **câbles et prises** de l'hôtel |

### 2.4 Ce qui se passe quand on crée une VM dans OpenStack

1. Tu demandes une VM. **Keystone** vérifie ton identité et te donne un jeton.
2. **Nova** reçoit la demande.
3. **Placement** répond « il reste de la place sur tel serveur ».
4. Nova va chercher l'image dans **Glance**.
5. **Neutron** branche la VM sur un réseau et lui donne une adresse IP.
6. Nova démarre la VM avec l'hyperviseur (ici **QEMU**).
7. Si on veut la joindre depuis l'extérieur, on lui ajoute une **IP flottante** (expliquée plus bas).

:::info
🧠 **À retenir :** OpenStack = des services spécialisés qui travaillent ensemble. Keystone pour l'identité, Nova pour les VM, Neutron pour le réseau, Glance pour les images, Placement pour les ressources, Horizon pour le site web.
:::

### 2.5 Docker et les conteneurs

:::info
📖 **C'est quoi un conteneur ?**
C'est une **boîte** qui contient un programme **avec tout ce dont il a besoin** pour fonctionner : bibliothèques, configuration… La boîte s'exécute de façon isolée du reste du système. Un conteneur est beaucoup plus léger qu'une VM, parce qu'il **partage le noyau** du système hôte au lieu de simuler un ordinateur complet.
:::

:::info
📖 **C'est quoi Docker ?**
C'est le logiciel le plus connu pour créer et lancer des conteneurs.
:::

> **Analogie :** un conteneur, c'est comme un **conteneur maritime**. Peu importe ce qu'il y a dedans, il se manipule toujours de la même façon, et son contenu ne se mélange pas avec celui du voisin.

### 2.6 Ansible

:::info
📖 **C'est quoi Ansible ?**
C'est un outil d'**automatisation**. On lui donne une **recette**, appelée *playbook* (un fichier qui liste des tâches), et il exécute toutes les étapes à notre place : installer des paquets, copier des fichiers, démarrer des services…
:::

> **Analogie :** Ansible est un **chef cuisinier** qui suit une recette à la lettre, sans jamais oublier une étape.

### 2.7 Kolla-Ansible

:::info
📖 **C'est quoi Kolla-Ansible ?**
- **Kolla** fournit chaque service OpenStack déjà emballé dans une **image Docker**, prête à l'emploi.
- **Ansible** installe et configure tout automatiquement.
:::

Ensemble, ils déploient OpenStack en **une douzaine de minutes**, au lieu de plusieurs jours à la main.

:::info
📖 **C'est quoi « All-in-One » (AIO) ?**
« Tout-en-un » : **tous** les rôles d'OpenStack sont sur **une seule machine**. Normalement, ils sont répartis sur plusieurs serveurs : contrôleur (le cerveau), compute (qui fait tourner les VM), réseau. C'est parfait pour apprendre, mais **jamais utilisé en production**, parce que si la machine tombe, tout tombe.
:::

### 2.8 La virtualisation imbriquée, VT-x, KVM et QEMU

:::info
📖 **C'est quoi la virtualisation imbriquée ?**
C'est faire tourner une VM **à l'intérieur** d'une autre VM. C'est notre cas :
:::

```
PC Windows  →  VM Ubuntu (VMware)  →  VM Cirros (OpenStack)
 (le vrai)      (1ʳᵉ couche)           (2ᵉ couche, « imbriquée »)
```

> **Analogie :** des **poupées russes**.

:::info
📖 **C'est quoi VT-x ?**
C'est une fonction **intégrée au processeur Intel** qui accélère énormément la virtualisation. AMD a l'équivalent, AMD-V.
:::

:::info
📖 **KVM et QEMU, c'est quoi ?**
Ce sont deux façons de faire tourner les VM sous Linux :
- **KVM** utilise VT-x : c'est **rapide**, presque la vitesse réelle.
- **QEMU seul** **imite** un processeur entièrement par logiciel : ça marche **sans VT-x**, mais c'est **beaucoup plus lent**.
:::

:::success
💡 **Pourquoi on a utilisé QEMU ?**
Sur mon PC, l'option de VMware « **Virtualiser Intel VT-x/EPT** » doit rester **décochée**. Sinon, la VM ne démarre pas, à cause d'un conflit avec Hyper-V, la virtualisation intégrée de Windows (constaté au TP ESXi). Résultat : la VM Ubuntu ne « voit » pas VT-x, donc KVM est impossible. On dit donc à OpenStack d'utiliser **QEMU**. C'est plus lent, mais largement suffisant pour une petite VM de test.
:::

:::info
🧠 **À retenir :** pas de VT-x dans la VM, donc pas de KVM, donc `nova_compute_virt_type: qemu`.
:::

---

## 3. Les bases du réseau (indispensable)

Le réseau est la partie la plus difficile d'OpenStack. Voici tout ce qu'il faut savoir, depuis zéro.

### 3.1 Adresse IP

:::info
📖 **C'est quoi une adresse IP ?**
C'est l'**adresse postale** d'une machine sur un réseau. Elle s'écrit avec 4 nombres de 0 à 255, séparés par des points. Exemple : `192.168.190.10`.
:::

### 3.2 Le « /24 » (masque de sous-réseau)

:::info
📖 **C'est quoi « /24 » ?**
Il indique **quelle partie de l'adresse désigne le réseau** et quelle partie désigne la machine.
- `/24` = les **3 premiers nombres** désignent le réseau, le **dernier** désigne la machine.
- Donc `192.168.190.0/24` = toutes les adresses de `192.168.190.1` à `192.168.190.254`.
:::

> **Analogie :** `192.168.190` = le nom de la **rue**, et le dernier nombre = le **numéro de la maison**. Toutes les machines en `192.168.190.x` habitent dans la même rue et peuvent se parler directement.

### 3.3 Passerelle, DNS et DHCP

:::info
📖 **Passerelle (gateway)** : la « porte de sortie » du réseau, la machine à qui on envoie tout ce qui doit aller **ailleurs**, vers Internet par exemple. C'est le rôle de ta box à la maison.
:::

:::info
📖 **DNS** : l'**annuaire** d'Internet. Il traduit un nom (`google.com`) en adresse IP (`142.250.x.x`).
:::

:::info
📖 **DHCP** : un service qui **distribue automatiquement** les adresses IP aux machines qui arrivent sur le réseau, pour ne pas avoir à les configurer à la main.
:::

### 3.4 Le NAT

:::info
📖 **C'est quoi le NAT ?**
*Network Address Translation*, la « traduction d'adresses ». Un routeur **remplace une adresse par une autre** quand un paquet le traverse.
- **SNAT** (S pour *Source*) : permet à plein de machines d'un réseau privé de **sortir** sur Internet en partageant une seule adresse. C'est ce que fait ta box.
- **DNAT** (D pour *Destination*) : permet de **rentrer** depuis l'extérieur vers une machine précise du réseau privé.
:::

### 3.5 Carte réseau et interface

:::info
📖 **C'est quoi une carte réseau (ou interface) ?**
C'est la « prise réseau » d'une machine. Sous Ubuntu, elles ont des noms comme `ens33` ou `ens34`. Notre VM en a **deux**.
:::

### 3.6 Le réseau NAT de VMware (VMnet8)

:::info
📖 **C'est quoi VMnet8 ?**
C'est un **réseau virtuel créé par VMware** sur ton PC. Les VM branchées dessus :
- peuvent se parler entre elles ;
- peuvent parler à ton PC Windows ;
- peuvent sortir sur Internet grâce au NAT de VMware.
:::

Sur mon PC, VMnet8 utilise les adresses `192.168.190.0/24` :
- `192.168.190.2` = la passerelle et le DNS de VMware ;
- `192.168.190.1` = ton PC Windows sur ce réseau ;
- `.128` à `.254` = la plage que le DHCP de VMware distribue automatiquement.

📸 *Capture 02 – L'éditeur de réseau virtuel de VMware (VMnet8 en NAT)*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/02-vmware-vmnet8.png)

📸 *Capture 03 – La passerelle du NAT (192.168.190.2)*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/03-vmware-nat-passerelle.png)

📸 *Capture 04 – La plage DHCP (.128 à .254)*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/04-vmware-dhcp.png)

### 3.7 La VIP

:::info
📖 **C'est quoi une VIP ?**
*Virtual IP*, une « adresse IP virtuelle ». C'est une adresse qui n'appartient à aucune carte réseau en particulier : un service (ici **HAProxy**, aidé par **keepalived**) la « porte ». C'est **le point d'entrée unique** de tout OpenStack : toutes les demandes (site web, commandes…) arrivent dessus. Avec plusieurs serveurs, si l'un tombe, la VIP passe automatiquement sur un autre.
:::

### 3.8 L'IP flottante

:::info
📖 **C'est quoi une IP flottante ?**
C'est une adresse du **réseau extérieur** qu'on « accroche » à une VM du cloud pour pouvoir la **joindre depuis l'extérieur**.
- La VM, elle, ne connaît **que son adresse privée** (`10.10.10.x`).
- C'est le **routeur virtuel** qui fait la traduction (DNAT/SNAT, en « 1 pour 1 ») entre l'IP flottante et l'IP privée.
- On l'appelle « flottante » parce qu'on peut la **décrocher** d'une VM et l'**accrocher** à une autre en une commande.
:::

> **Analogie :** l'IP privée, c'est le **numéro de chambre** dans l'hôtel. L'IP flottante, c'est un **numéro de téléphone direct** que la réception redirige vers ta chambre. Si tu changes de chambre, on redirige le numéro vers la nouvelle.

:::info
🧠 **À retenir :** les VM d'un même réseau privé se parlent déjà entre elles. L'IP flottante sert **uniquement** à les joindre **depuis l'extérieur**.
:::

---

## 4. Architecture et plan d'adressage du TP

### 4.1 Le schéma complet

```
                        Internet
                           │
              ┌────────────┴─────────────┐
              │ NAT VMware (VMnet8)      │  192.168.190.0/24
              │ passerelle/DNS : .2      │
              └──┬───────────────┬───────┘
                 │               │
     PC Windows (.1)             │
                    ┌────────────┴──────────────────────────────────┐
                    │ VM Ubuntu « openstack-aio »                   │
                    │                                               │
                    │  ens33 : 192.168.190.10  → administration     │
                    │          + VIP .11 (API et site Horizon)      │
                    │                                               │
                    │  ens34 : PAS d'IP → donnée à Neutron          │
                    │     │                                         │
                    │   br-ex (switch virtuel, « physnet1 »)        │
                    │     │                                         │
                    │   réseau « public » ── router1 (.113 / 10.10.10.1)
                    │                            │                  │
                    │                 réseau « private » 10.10.10.0/24
                    │                            │                  │
                    │                  vm-cirros 10.10.10.91        │
                    │                  (IP flottante 192.168.190.105)│
                    └───────────────────────────────────────────────┘
```

### 4.2 Le plan d'adressage (qui a quelle adresse)

| Élément | Adresse | Explication |
|---|---|---|
| Réseau VMnet8 | `192.168.190.0/24` | La « rue » du réseau VMware |
| Passerelle et DNS VMware | `192.168.190.2` | La sortie vers Internet |
| PC Windows | `192.168.190.1` | Ton PC vu depuis ce réseau |
| DHCP VMware | `.128` → `.254` | On choisit nos adresses fixes **en dehors** de cette plage, pour éviter les doublons |
| Ubuntu, carte `ens33` | `192.168.190.10` | Adresse fixe pour administrer la VM |
| Ubuntu, carte `ens34` | **aucune** | Réservée à Neutron (voir ci-dessous) |
| VIP Kolla | `192.168.190.11` | Le point d'entrée d'OpenStack |
| IP flottantes | `.100` → `.120` | Les 21 adresses qu'OpenStack peut distribuer |
| Réseau privé OpenStack | `10.10.10.0/24` | Le réseau interne où vivent les VM du cloud |

### 4.3 Pourquoi deux cartes réseau ?

- **`ens33`** sert à **administrer** : on s'y connecte en SSH, et OpenStack y fait tourner ses API et son site web.
- **`ens34`** sert de **« câble » entre le cloud et le monde extérieur**. Neutron la branche sur un switch virtuel nommé `br-ex`.

:::success
💡 **Pourquoi `ens34` n'a pas d'adresse IP ?**
Parce que c'est **Neutron** qui s'en occupe entièrement. Si Ubuntu y mettait aussi une adresse, **Ubuntu et Neutron se disputeraient** la même carte, et le réseau ne marcherait pas.
:::

---

## 5. Étape 1 – Créer la machine virtuelle dans VMware

### 5.1 Choisir la bonne version d'Ubuntu

:::success
💡 **Pourquoi Ubuntu 24.04 et pas la toute dernière (26.04) ?**
Chaque version d'OpenStack ne fonctionne qu'avec certaines versions de Linux. La **version 2025.2** d'OpenStack (celle de ce TP) est prévue pour **Ubuntu 24.04**. La 26.04, proposée par défaut sur le site d'Ubuntu, **n'est pas supportée**. On a donc téléchargé **Ubuntu Server 24.04.5 LTS**.
:::

:::info
📖 **LTS** = *Long Term Support* : version maintenue pendant 5 ans, donc stable.
📖 **Server** = version **sans interface graphique**, uniquement en ligne de commande. Elle est plus légère.
:::

📸 *Capture 01 – Téléchargement d'Ubuntu Server 24.04.5*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/01-ubuntu-telechargement-24-04-5.png)

### 5.2 Paramètres de la VM

Dans VMware Workstation : *Fichier → Nouvelle machine virtuelle → Personnalisée (avancée)*.

| Paramètre | Valeur | 💡 Pourquoi ? |
|---|---|---|
| Système | Linux – Ubuntu 64 bits | |
| Emplacement | `D:\VM\openstack-aio` | Le disque D: a de la place libre |
| Processeurs | 8 cœurs | OpenStack lance une quarantaine de conteneurs |
| Mémoire | 16 Go | Le minimum confortable pour un All-in-One |
| Disque | 100 Go | Pour les images Docker et les VM du cloud |
| Carte réseau 1 | NAT (VMnet8) | Deviendra `ens33` (administration) |
| Carte réseau 2 | NAT (VMnet8) | Deviendra `ens34` (pour Neutron) |
| « Virtualiser Intel VT-x/EPT » | **Décoché** | Sinon la VM ne démarre pas sur ce PC (voir §2.8) |

📸 *Capture 05 – La mémoire de la VM (16 Go). La 2ᵉ carte réseau a été ajoutée juste après cette capture : on la voit sur la capture 16.*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/05-vm-parametres.png)

📸 *Capture 06 – VT-x/EPT décoché*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/06-vm-processeurs-vtx-decoche.png)

---

## 6. Étape 2 – Installer Ubuntu Server 24.04

On démarre la VM sur l'ISO d'Ubuntu (le fichier d'installation), puis on suit l'installateur :

| Écran | Choix | 💡 Pourquoi ? |
|---|---|---|
| Langue | English | Les messages d'erreur en anglais sont plus faciles à chercher sur Internet |
| Clavier | Switzerland – French | Mon clavier physique est suisse QWERTZ |
| Type | Ubuntu Server | |
| Réseau `ens33` | Manuel : `192.168.190.10/24`, passerelle `.2`, DNS `192.168.190.2, 8.8.8.8` | Une adresse **fixe** ne change jamais, et OpenStack en a besoin |
| Réseau `ens34` | Disabled | Elle ne doit pas avoir d'IP (voir §4.3) |
| Disque | Disque entier, **sans LVM** | Avec LVM, Ubuntu n'utilise qu'une partie du disque par défaut |
| Profil | Serveur `openstack-aio`, utilisateur `lami` | |
| SSH | **Install OpenSSH server** coché | Pour piloter la VM depuis Windows (voir §7.1) |

📸 *Capture 07 – Configuration réseau*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/07-ubuntu-install-reseau.png)

📸 *Capture 08 – Configuration du disque*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/08-ubuntu-install-disque.png)

📸 *Capture 09 – Installation du serveur SSH*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/09-ubuntu-install-ssh.png)

📸 *Capture 10 – Installation terminée*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/10-ubuntu-installation-terminee.png)

📸 *Capture 11 – Première connexion*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/11-ubuntu-premier-login.png)

:::warning
⚠️ **Attention :** Linux fait la différence entre **majuscules et minuscules**. L'utilisateur est `lami`, pas `Lami`.
:::

---

## 7. Étape 3 – Préparer Ubuntu

### 7.1 Se connecter en SSH depuis Windows

:::info
📖 **C'est quoi SSH ?**
*Secure Shell*. C'est un moyen de **piloter une machine à distance**, en ligne de commande, de façon **chiffrée** (personne ne peut lire ce qui passe).
:::

:::success
💡 **Pourquoi ne pas taper directement dans la fenêtre VMware ?**
Avec SSH depuis PowerShell, on peut **copier-coller** les commandes, la fenêtre est plus confortable, et c'est comme ça qu'on travaille sur de vrais serveurs.
:::

🪟 **Windows** (PowerShell : touche Windows + R, puis `powershell`) :
```powershell
ssh lami@192.168.190.10
```
- `ssh` : le programme de connexion ;
- `lami` : l'utilisateur ;
- `@192.168.190.10` : sur quelle machine.

La première fois, SSH demande si on fait confiance au serveur (son « empreinte ») : on répond `yes`.

📸 *Capture 12*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/12-ssh-depuis-windows.png)

### 7.2 Mettre Ubuntu à jour

🐧 **Ubuntu** :
```bash
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```
| Morceau | Signification |
|---|---|
| `sudo` | « Exécute en tant qu'administrateur » (*super user do*). Demande ton mot de passe. |
| `apt` | Le gestionnaire de logiciels d'Ubuntu (comme un App Store en ligne de commande) |
| `apt update` | Télécharge la **liste** des dernières versions disponibles |
| `&&` | « Puis, si la commande d'avant a réussi » |
| `apt full-upgrade` | Installe les **mises à jour** |
| `-y` | Répond automatiquement « oui » aux questions |
| `reboot` | Redémarre la machine |

:::warning
⚠️ **Attention : ne jamais lancer `do-release-upgrade`.**
Ubuntu affiche « *New release '26.04' available* ». **On ignore ce message.**
- `apt full-upgrade` = met à jour les logiciels **en restant en 24.04**. ✅
- `do-release-upgrade` = fait passer **à Ubuntu 26.04**, que Kolla 2025.2 ne supporte pas. ❌
:::

📸 *Capture 13*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/13-ubuntu-mises-a-jour.png)

### 7.3 Activer `ens34` sans lui donner d'IP

:::info
📖 **C'est quoi netplan ?**
C'est l'outil d'Ubuntu qui configure les cartes réseau, à partir de fichiers texte au format YAML, rangés dans `/etc/netplan/`.
:::

:::info
📖 **C'est quoi le YAML ?**
Un format de fichier texte très lisible, organisé avec des **décalages** (indentation). ⚠️ Les espaces comptent : un décalage faux = une erreur.
:::

🐧 **Ubuntu** :
```bash
sudo tee /etc/netplan/60-ens34.yaml > /dev/null <<'EOF'
network:
  version: 2
  ethernets:
    ens34:
      dhcp4: false
      dhcp6: false
      optional: true
EOF
sudo chmod 600 /etc/netplan/60-ens34.yaml
sudo netplan apply
ip -br a
```

**Ce que fait chaque ligne :**
- `sudo tee … <<'EOF' … EOF` : écrit tout le texte entre les deux `EOF` dans le fichier `/etc/netplan/60-ens34.yaml`.
- Dans le fichier :
  - `ens34:` : on parle de la 2ᵉ carte ;
  - `dhcp4: false` et `dhcp6: false` : **pas d'adresse automatique** ;
  - `optional: true` : « ne bloque pas le démarrage en attendant cette carte » (voir le problème du §12.1).
- `chmod 600` : seul l'administrateur peut lire ce fichier (netplan l'exige).
- `netplan apply` : applique la configuration.
- `ip -br a` : affiche les cartes et leurs adresses, en bref (*brief*).

**Ce qu'on doit voir :**
- `ens33  UP  192.168.190.10/24`
- `ens34  UP`, sans adresse IPv4

📸 *Capture 14* (la capture montre la première version du fichier : la ligne `optional: true` a été ajoutée juste après, voir §12.1)
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/14-ip-cartes-reseau.png)

### 7.4 Vérifier que la machine est prête

🐧 **Ubuntu** :

| Commande | Ce qu'elle fait | Résultat obtenu | Ce que ça prouve |
|---|---|---|---|
| `hostname` | Affiche le nom de la machine | `openstack-aio` | Le nom est bon |
| `nproc` | Compte les processeurs | `8` | Les 8 vCPU sont là |
| `free -h` | Affiche la mémoire | `15Gi` | Les 16 Go sont là |
| `df -h /` | Affiche l'espace disque | `98G` | Le disque de 100 Go est bien utilisé |
| `egrep -c '(vmx\|svm)' /proc/cpuinfo` | Cherche VT-x (`vmx`) ou AMD-V (`svm`) dans le processeur | `0` | **Pas de VT-x**, donc il faudra QEMU |
| `ping -c 3 google.com` | Envoie 3 « coucou » à Google | `0% packet loss` | Internet et le DNS fonctionnent |

📸 *Capture 15*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/15-verifications-serveur.png)

### 7.5 Prendre un instantané (snapshot)

:::info
📖 **C'est quoi un snapshot ?**
Une **photo** de la VM à un instant donné. Si on casse quelque chose plus tard, on peut **revenir** à cette photo en un clic. C'est comme un point de sauvegarde dans un jeu vidéo.
:::

VM éteinte (`sudo poweroff`), puis dans VMware : *VM → Instantané → Prendre un instantané*, nommé **`ubuntu-propre`**.

📸 *Capture 16*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/16-vmware-snapshot-ubuntu-propre.png)

---

## 8. Étape 4 – Installer Kolla-Ansible

### 8.1 Installer les outils et créer un environnement Python isolé

:::info
📖 **C'est quoi Python et pip ?**
**Python** est un langage de programmation : Kolla-Ansible et Ansible sont écrits en Python. **pip** est l'installateur de modules Python.
:::

:::info
📖 **C'est quoi un venv ?**
Un *virtual environment* (environnement virtuel Python). C'est un **dossier isolé** qui contient sa propre copie de Python et de ses modules.
:::

:::success
💡 **Pourquoi un venv ?**
Ubuntu utilise lui-même Python pour fonctionner. Si on installait Kolla directement dans le Python d'Ubuntu, on risquerait de **casser** Ubuntu à cause de versions de modules incompatibles. Avec le venv, tout reste rangé dans son coin.
:::

> **Analogie :** le venv, c'est une **boîte à outils séparée** pour ce projet. On n'y mélange pas les outils de la maison.

🐧 **Ubuntu** :
```bash
sudo apt install -y git python3-dev libffi-dev gcc libssl-dev libdbus-glib-1-dev python3-venv
python3 -m venv ~/kolla-venv
source ~/kolla-venv/bin/activate
pip install -U pip
```
- `apt install …` : installe les outils nécessaires. `git` sert à télécharger du code ; `gcc` et les `-dev` servent à compiler certains modules Python.
- `python3 -m venv ~/kolla-venv` : crée le venv dans le dossier `kolla-venv` de ton dossier personnel. `~` veut dire « mon dossier personnel » (`/home/lami`).
- `source ~/kolla-venv/bin/activate` : **active** le venv. On voit alors `(kolla-venv)` au début de la ligne.
- `pip install -U pip` : met pip à jour.

:::warning
⚠️ **Attention :** le venv doit être **réactivé à chaque nouvelle connexion SSH** avec `source ~/kolla-venv/bin/activate`. Si `(kolla-venv)` n'apparaît pas au début de la ligne, les commandes `kolla-ansible` et `openstack` ne marcheront pas.
:::

### 8.2 Installer Kolla-Ansible version 2025.2

🐧 **Ubuntu** (venv activé) :
```bash
pip install git+https://opendev.org/openstack/kolla-ansible@stable/2025.2
```
- `git+https://…` : télécharge le code directement depuis le site officiel d'OpenStack.
- `@stable/2025.2` : la branche **stable** de la version **2025.2**, qui correspond à Ubuntu 24.04.

Résultat : **kolla-ansible 21.3.1** (le numéro de Kolla pour OpenStack 2025.2) et **ansible-core 2.19**.

📸 *Capture 17*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/17-kolla-ansible-installe.png)

### 8.3 Copier les fichiers de configuration et l'inventaire

:::info
📖 **C'est quoi l'inventaire ?**
Un fichier qui dit à Ansible **sur quelles machines** installer **quoi**. Le fichier `all-in-one` dit : « tout sur cette machine (`localhost`) ».
:::

🐧 **Ubuntu** :
```bash
sudo mkdir -p /etc/kolla
sudo chown $USER:$USER /etc/kolla
cp -r ~/kolla-venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
cp ~/kolla-venv/share/kolla-ansible/ansible/inventory/all-in-one ~/
```
- `mkdir -p /etc/kolla` : crée le dossier de configuration de Kolla.
- `chown $USER:$USER` : donne ce dossier à l'utilisateur `lami`, pour pouvoir y écrire sans `sudo`.
- `cp -r …/kolla/* /etc/kolla` : copie les fichiers modèles, `globals.yml` (les réglages) et `passwords.yml` (les mots de passe, encore vides).
- `cp …/all-in-one ~/` : copie l'inventaire dans ton dossier personnel.

📸 *Capture 18*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/18-kolla-fichiers-config.png)

### 8.4 Installer les dépendances et générer les mots de passe

🐧 **Ubuntu** :
```bash
kolla-ansible install-deps
kolla-genpwd
```
- `install-deps` : installe les **collections Ansible**, c'est-à-dire les « modules complémentaires » dont Kolla a besoin.
- `kolla-genpwd` : **génère automatiquement un mot de passe aléatoire** pour chaque service (base de données, RabbitMQ, compte admin…) et les écrit dans `/etc/kolla/passwords.yml`.

:::danger
🔒 **Secret :** `passwords.yml` contient **tous les mots de passe** du cloud. Il n'est **jamais** publié, ni le fichier, ni son contenu, ni en capture d'écran.
:::

📸 *Capture 19*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/19-kolla-install-deps-genpwd.png)

---

## 9. Étape 5 – Configurer Kolla-Ansible

### 9.1 Vérifier que l'adresse de la VIP est libre

🐧 **Ubuntu** :
```bash
ping -c 2 192.168.190.11
```
On **veut** une erreur (`Destination Host Unreachable`). Ça prouve que **personne** n'utilise déjà cette adresse, donc on peut la donner à la VIP.

### 9.2 Écrire nos réglages

:::success
💡 **Pourquoi un fichier dans `globals.d/` plutôt que modifier `globals.yml` ?**
`globals.yml` est un énorme fichier de plus de 800 lignes, presque toutes en commentaire. En mettant **nos** réglages dans un petit fichier séparé, on voit d'un coup d'œil ce qu'on a changé. Kolla lit automatiquement tous les fichiers de `globals.d/`.
:::

🐧 **Ubuntu** :
```bash
mkdir -p /etc/kolla/globals.d
cat > /etc/kolla/globals.d/00-aio.yml <<'EOF'
kolla_base_distro: "ubuntu"
network_interface: "ens33"
neutron_external_interface: "ens34"
kolla_internal_vip_address: "192.168.190.11"
enable_haproxy: "yes"
enable_horizon: "yes"
enable_neutron_provider_networks: "yes"
nova_compute_virt_type: "qemu"
EOF
```

**Chaque réglage expliqué :**

| Réglage | Valeur | Ce que ça veut dire |
|---|---|---|
| `kolla_base_distro` | `ubuntu` | Les conteneurs sont construits sur Ubuntu |
| `network_interface` | `ens33` | La carte pour **administrer** et faire parler les services entre eux |
| `neutron_external_interface` | `ens34` | La carte **sans IP** que Neutron utilise comme « câble » vers l'extérieur |
| `kolla_internal_vip_address` | `192.168.190.11` | L'adresse **unique** pour joindre OpenStack (API et site web) |
| `enable_haproxy` | `yes` | Active le répartiteur qui porte la VIP |
| `enable_horizon` | `yes` | Active le site web |
| `enable_neutron_provider_networks` | `yes` | Autorise un réseau branché sur le **vrai** réseau extérieur (pour les IP flottantes) |
| `nova_compute_virt_type` | `qemu` | Utilise QEMU, parce que KVM est impossible (pas de VT-x, voir §2.8) |

📸 *Capture 20*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/20-kolla-globals-aio.png)

### 9.3 Autoriser `sudo` sans mot de passe

:::success
💡 **Pourquoi ?**
Ansible lance des centaines de commandes en administrateur. Sans ce réglage, il devrait demander le mot de passe à chaque fois. C'est une pratique courante **en labo**, mais à éviter en production.
:::

🐧 **Ubuntu** :
```bash
echo "lami ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/lami
sudo chmod 440 /etc/sudoers.d/lami
```
- La ligne `lami ALL=(ALL) NOPASSWD:ALL` veut dire : « lami peut tout faire en administrateur, sans mot de passe ».
- `chmod 440` : le fichier est en lecture seule, comme l'exige `sudo`.

---

## 10. Étape 6 – Déployer OpenStack

Le déploiement se fait en **4 commandes**, toujours dans le même ordre :

| Ordre | Commande | Rôle | Analogie (construire une maison) |
|---|---|---|---|
| 1 | `bootstrap-servers` | Prépare la machine : installe Docker, configure le système | **Préparer le terrain** |
| 2 | `prechecks` | Vérifie que tout est prêt **avant** d'installer | **Contrôle avant travaux** |
| 3 | `deploy` | Télécharge et lance tous les conteneurs OpenStack | **Construire la maison** |
| 4 | `post-deploy` | Crée les fichiers de connexion pour l'administrateur | **Remettre les clés** |

### 10.1 Préparer le serveur (bootstrap)

🐧 **Ubuntu** :
```bash
kolla-ansible bootstrap-servers -i ~/all-in-one
```
`-i ~/all-in-one` = « utilise cet inventaire ».

:::info
📖 **Comment lire le résultat d'Ansible (le `PLAY RECAP`) :**
- `ok` = tâches réussies ;
- `changed` = tâches qui ont **modifié** quelque chose ;
- `failed` = **erreurs**. **Il faut toujours 0.**
:::

Résultat : `ok=44 changed=16 failed=0` ✅

📸 *Capture 21*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/21-kolla-bootstrap-servers.png)

### 10.2 Vérifier avant d'installer (prechecks)

🐧 **Ubuntu** :
```bash
kolla-ansible prechecks -i ~/all-in-one
```
Le premier essai a **échoué** (`No module named 'docker'`, expliqué au §12.2). Après correction : `ok=104 failed=0` ✅

📸 *Capture 22a – L'erreur*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/22a-prechecks-erreur-docker-sdk.png)

📸 *Capture 22 – Le succès après correction*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/22-kolla-prechecks.png)

### 10.3 Déployer (deploy)

:::info
📖 **C'est quoi tmux ?**
Un programme qui garde une session de terminal **vivante même si la connexion SSH coupe**. C'est indispensable pour une commande longue : si PowerShell se ferme, le déploiement continue. On se rattache avec `tmux attach -t deploy`.
:::

🐧 **Ubuntu** :
```bash
tmux new -s deploy
source ~/kolla-venv/bin/activate
kolla-ansible deploy -i ~/all-in-one
```
- `tmux new -s deploy` : ouvre une session tmux nommée `deploy`.
- On réactive le venv, parce que la session tmux est un nouveau terminal.
- `deploy` : Kolla télécharge les images Docker (`quay.io/openstack.kolla/…:2025.2-ubuntu-noble`) et démarre chaque service.

Résultat : **`ok=427 changed=273 failed=0`**, en **12 minutes environ** ✅
(Le `ignored=1` n'est pas une erreur : c'est un test dont l'échec est prévu et toléré par Kolla.)

📸 *Capture 23*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/23-kolla-deploy.png)

### 10.4 Après le déploiement (post-deploy) et client OpenStack

🐧 **Ubuntu** :
```bash
kolla-ansible post-deploy -i ~/all-in-one
pip install python-openstackclient -c https://releases.openstack.org/constraints/upper/2025.2
source /etc/kolla/admin-openrc.sh
```
- `post-deploy` crée `/etc/kolla/admin-openrc.sh` et `/etc/kolla/clouds.yaml` : ce sont les **identifiants de l'administrateur** du cloud.
- `pip install python-openstackclient` installe la commande `openstack`, qui sert à piloter le cloud en ligne de commande.
  - `-c …/2025.2` (*constraints*) oblige pip à prendre des versions **compatibles avec OpenStack 2025.2**.
- `source admin-openrc.sh` « charge » les identifiants dans le terminal. Ensuite, les commandes `openstack` savent **qui tu es**.

:::warning
⚠️ **Attention :** comme le venv, `source /etc/kolla/admin-openrc.sh` est à refaire **à chaque nouvelle connexion**.
:::

:::danger
🔒 **Secret :** `admin-openrc.sh` et `clouds.yaml` contiennent le mot de passe admin. On ne les publie jamais.
:::

📸 *Capture 24*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/24-kolla-post-deploy.png)

### 10.5 Vérifier que tout fonctionne

🐧 **Ubuntu** :
```bash
openstack service list
openstack compute service list
openstack network agent list
sudo docker ps --format "table {{.Names}}\t{{.Status}}"
```

| Commande | Ce qu'elle montre | Résultat obtenu |
|---|---|---|
| `openstack service list` | Le **catalogue** de Keystone : la liste des services installés | keystone, glance, nova, neutron, placement, heat, heat-cfn ✅ |
| `openstack compute service list` | L'état des morceaux de Nova | `nova-scheduler` (choisit où placer la VM), `nova-conductor` (fait le lien avec la base), `nova-compute` (lance les VM) : tous **enabled / up** ✅ |
| `openstack network agent list` | L'état des agents Neutron | L3 (routeurs), DHCP (distribue les IP), Metadata (donne les infos à la VM, comme la clé SSH), Open vSwitch (switch virtuel) : tous **:-) / UP** ✅ |
| `docker ps` | Les conteneurs qui tournent | Environ 40 conteneurs, tous **Up**, et **(healthy)** pour ceux qui ont un test de santé ✅ |

📸 *Capture 25 – Catalogue des services*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/25-openstack-service-list.png)

📸 *Capture 26 – Services Nova et agents Neutron*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/26-openstack-services-up.png)

📸 *Capture 27 – Conteneurs Docker*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/27-docker-conteneurs.png)

:::info
🧠 **À retenir :** à ce stade, OpenStack est **installé et en bonne santé**, mais il est **vide**. Il n'y a encore ni image, ni réseau, ni VM.
:::

---

## 11. Étape 7 – Créer et tester une première VM dans OpenStack

Pour lancer une VM, OpenStack a besoin de **6 ingrédients**. On les prépare un par un :

| # | Ingrédient | Service | Analogie |
|---|---|---|---|
| 1 | Une **image** | Glance | Le **système** à installer |
| 2 | Un **gabarit** (flavor) | Nova | La **taille** de la VM (S, M, L) |
| 3 | Un **réseau** (public + privé) | Neutron | Les **routes** |
| 4 | Un **routeur** | Neutron | Le **carrefour** entre les routes |
| 5 | Un **groupe de sécurité** | Neutron | Le **videur** à l'entrée |
| 6 | Une **paire de clés** | Nova | La **clé** de la porte |

Toutes les commandes `openstack` sont tapées sur 🐧 **Ubuntu**, avec `(kolla-venv)` activé et `admin-openrc.sh` chargé.

### 11.1 Ingrédient 1 : l'image Cirros

:::info
📖 **C'est quoi Cirros ?**
Un Linux **minuscule** (environ 20 Mo), fait exprès pour **tester** un cloud. Il démarre vite, même avec QEMU qui est lent.
:::

:::info
📖 **C'est quoi qcow2 ?**
Un format de disque virtuel (*QEMU Copy On Write*). Il ne prend sur le disque que la place réellement utilisée.
:::

🐧 **Ubuntu** :
```bash
wget https://download.cirros-cloud.net/0.6.3/cirros-0.6.3-x86_64-disk.img
openstack image create --disk-format qcow2 --container-format bare --public \
  --file cirros-0.6.3-x86_64-disk.img cirros
openstack image list
```
- `wget` : télécharge le fichier depuis Internet.
- `openstack image create` : envoie l'image dans Glance, avec ces options :
  - `--disk-format qcow2` : le format du disque ;
  - `--container-format bare` : l'image n'est pas emballée dans autre chose ;
  - `--public` : tous les projets du cloud peuvent l'utiliser ;
  - `--file …` : le fichier à envoyer ;
  - `cirros` : le nom qu'on donne à l'image.
- Le `\` en fin de ligne veut dire « la commande continue à la ligne suivante ».

Résultat : l'image `cirros` est **active** ✅

📸 *Capture 28*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/28-glance-image-cirros.png)

### 11.2 Ingrédient 2 : le gabarit (flavor)

:::info
📖 **C'est quoi un flavor ?**
Le **modèle de taille** d'une VM : nombre de processeurs, quantité de mémoire, taille du disque. C'est comme choisir une taille S, M ou L chez un hébergeur. Kolla n'en crée **aucun** par défaut.
:::

🐧 **Ubuntu** :
```bash
openstack flavor create --vcpus 1 --ram 256 --disk 1 m1.tiny
openstack flavor list
```
`--vcpus 1` = 1 processeur, `--ram 256` = 256 Mo de mémoire, `--disk 1` = 1 Go de disque, et `m1.tiny` est le nom. C'est suffisant pour Cirros.

📸 *Capture 29*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/29-flavor-m1-tiny.png)

### 11.3 Ingrédient 3a : le réseau externe « public »

:::success
💡 **Pourquoi deux réseaux ?**
- **`public`** = la représentation, dans OpenStack, du **vrai** réseau VMware (`192.168.190.0/24`). C'est par lui qu'on entre et qu'on sort.
- **`private`** = un réseau **interne** au cloud (`10.10.10.0/24`), où vivent les VM.
:::

> **Analogie :** `public`, c'est la **rue**. `private`, c'est le **couloir intérieur** de l'immeuble. Le routeur, c'est la **porte d'entrée** entre les deux.

🐧 **Ubuntu** :
```bash
openstack network create --external --provider-network-type flat \
  --provider-physical-network physnet1 public
openstack subnet create --network public --subnet-range 192.168.190.0/24 \
  --gateway 192.168.190.2 --allocation-pool start=192.168.190.100,end=192.168.190.120 \
  --no-dhcp public-subnet
```

:::info
📖 **Réseau ou sous-réseau ?**
- Le **réseau** (*network*) = le « câble ».
- Le **sous-réseau** (*subnet*) = les **adresses** qu'on utilise sur ce câble.
:::

| Option | Ce que ça veut dire |
|---|---|
| `--external` | Ce réseau mène **vers l'extérieur** : il peut servir de sortie à un routeur et fournir des IP flottantes |
| `--provider-network-type flat` | Réseau « plat », **sans VLAN** : utilisé tel quel |
| `--provider-physical-network physnet1` | `physnet1` est le nom donné par Kolla au switch `br-ex`, lui-même branché sur **`ens34`**. C'est là qu'on relie le cloud au vrai réseau. |
| `--subnet-range 192.168.190.0/24` | Les adresses du réseau VMware |
| `--gateway 192.168.190.2` | La sortie Internet, c'est-à-dire la passerelle de VMware |
| `--allocation-pool start=…100,end=…120` | OpenStack n'a le droit de distribuer **que** les adresses .100 à .120 |
| `--no-dhcp` | **Pas** de DHCP OpenStack ici, car VMware en a déjà un sur ce réseau. Deux DHCP sur le même réseau = conflits. |

📸 *Capture 30*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/30-reseau-externe-public.png)

### 11.4 Ingrédient 3b : le réseau privé « private »

🐧 **Ubuntu** :
```bash
openstack network create private
openstack subnet create --network private --subnet-range 10.10.10.0/24 \
  --gateway 10.10.10.1 --dns-nameserver 192.168.190.2 private-subnet
```
- Ici, le DHCP est **activé** (c'est le comportement par défaut). C'est **Neutron** qui distribue automatiquement les adresses `10.10.10.x` aux VM.
- `--gateway 10.10.10.1` : l'adresse que prendra le routeur côté privé.
- `--dns-nameserver 192.168.190.2` : l'annuaire que les VM utiliseront, celui de VMware.

📸 *Capture 31*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/31-reseau-prive.png)

### 11.5 Ingrédient 4 : le routeur

:::info
📖 **C'est quoi un routeur ?**
Une machine qui **relie deux réseaux différents** et fait passer les paquets de l'un à l'autre. Ici, il est **virtuel** : c'est Neutron (l'agent L3) qui le fait tourner. C'est exactement le rôle de ta **box Internet** à la maison.
:::

🐧 **Ubuntu** :
```bash
openstack router create router1
openstack router set --external-gateway public router1
openstack router add subnet router1 private-subnet
openstack router show router1 -c name -c status -c external_gateway_info -c interfaces_info
```
1. `router create` : crée le routeur.
2. `set --external-gateway public` : branche sa **sortie** sur le réseau `public`. Il reçoit une adresse du pool : **192.168.190.113**.
3. `add subnet … private-subnet` : branche son **entrée** sur le réseau privé. Il prend **10.10.10.1**.
4. `router show -c …` : affiche seulement les colonnes (`-c`) utiles.

Le routeur fait aussi le **SNAT** (pour que les VM sortent sur Internet) et le **DNAT** des IP flottantes (pour entrer depuis l'extérieur).

📸 *Capture 32*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/32-routeur.png)

**Test intermédiaire :** est-ce que Windows voit le routeur ?

🪟 **Windows** (une **nouvelle** fenêtre PowerShell, pas connectée à Ubuntu) :
```powershell
ping 192.168.190.113
```
Résultat : **4 réponses sur 4** ✅
💡 Ça prouve que toute la chaîne fonctionne : Windows → VMnet8 → `ens34` → `br-ex` → routeur OpenStack.

:::warning
⚠️ **Attention :** sous **Windows**, `ping` s'arrête tout seul après 4 essais. Sous **Linux**, il ne s'arrête jamais : il faut appuyer sur **Ctrl + C** (ou utiliser `ping -c 3` pour n'en envoyer que 3).
:::

📸 *Capture 33*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/33-ping-routeur-depuis-windows.png)

### 11.6 Ingrédient 5 : le groupe de sécurité (pare-feu)

:::info
📖 **C'est quoi un groupe de sécurité ?**
C'est un **pare-feu** (firewall) collé à chaque VM. Il contient des **règles** qui disent quel trafic a le droit de passer.
- **Par défaut, tout ce qui ENTRE est bloqué** : ni ping, ni SSH.
- Tout ce qui **SORT** est autorisé.
:::

:::info
📖 **ingress / egress :**
- *ingress* = trafic **entrant** (vers la VM) ;
- *egress* = trafic **sortant** (de la VM).
:::

:::info
📖 **ICMP / TCP / port 22 :**
- **ICMP** = le protocole utilisé par `ping`.
- **TCP** = le protocole de la plupart des connexions (web, SSH…).
- Un **port** = un numéro de « porte » sur la machine. Chaque service écoute sur une porte précise : **22 = SSH**, 80 = web…
:::

🐧 **Ubuntu** :
```bash
openstack security group create ssh-icmp --description "Autorise ping et SSH"
openstack security group rule create --protocol icmp ssh-icmp
openstack security group rule create --protocol tcp --dst-port 22 ssh-icmp
openstack security group rule list ssh-icmp
```
1. Crée un groupe nommé `ssh-icmp`.
2. Ajoute une règle qui autorise le **ping** (ICMP) en entrée.
3. Ajoute une règle qui autorise le **SSH** (TCP, port de destination 22) en entrée.
4. Affiche les règles.

Résultat :
- 2 règles **ingress** (icmp, tcp 22) qu'on a ajoutées ;
- 2 règles **egress** (sortie IPv4 et IPv6), créées automatiquement ✅

:::success
💡 **Pourquoi un nouveau groupe plutôt que celui nommé `default` ?**
En tant qu'admin, il existe **plusieurs** groupes `default` (un par projet). La commande ne saurait pas lequel modifier.
:::

📸 *Capture 34*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/34-groupe-securite-ssh-icmp.png)

### 11.7 Ingrédient 6 : la paire de clés SSH

:::info
📖 **C'est quoi une paire de clés SSH ?**
Deux fichiers liés entre eux mathématiquement :
- la **clé publique** (`.pub`) se donne à qui on veut. On la met sur le serveur.
- la **clé privée** se garde **secrète**. Elle prouve que c'est bien toi.
:::

> **Analogie :** la clé publique, c'est un **cadenas** que tu donnes au serveur. La clé privée, c'est la **seule clé** qui ouvre ce cadenas, et tu la gardes dans ta poche.

:::success
💡 **Pourquoi une clé plutôt qu'un mot de passe ?**
Les images cloud (Cirros, Ubuntu Cloud…) s'utilisent normalement avec une clé. C'est **plus sûr** (impossible à deviner) et **plus pratique** (pas de mot de passe à taper).
:::

🐧 **Ubuntu** :
```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/openstack_key
openstack keypair create --public-key ~/.ssh/openstack_key.pub cle-lami
openstack keypair list
```
- `ssh-keygen` fabrique la paire de clés, avec ces options :
  - `-t ed25519` : un type de clé moderne et sûr ;
  - `-N ""` : sans phrase de passe ;
  - `-f …` : le nom du fichier. Ça crée `openstack_key` (privée) et `openstack_key.pub` (publique).
- `keypair create --public-key …` : donne la clé **publique** à OpenStack, sous le nom `cle-lami`. Au démarrage de la VM, l'agent **Metadata** la dépose dedans.

:::danger
🔒 **Secret :** la clé privée `openstack_key` n'est **jamais** publiée. La capture ne montre que l'**empreinte** (*fingerprint*), qui n'est pas secrète.
:::

📸 *Capture 35*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/35-keypair.png)

### 11.8 Lancer la VM (l'instance)

:::info
📖 **Instance** = le nom qu'on donne à une VM dans OpenStack.
:::

🐧 **Ubuntu** :
```bash
openstack server create --image cirros --flavor m1.tiny --network private \
  --security-group ssh-icmp --key-name cle-lami --wait vm-cirros
openstack server list
```
Une seule commande rassemble les 6 ingrédients :

| Option | Ingrédient |
|---|---|
| `--image cirros` | L'image (1) |
| `--flavor m1.tiny` | La taille (2) |
| `--network private` | Le réseau (3) |
| `--security-group ssh-icmp` | Le pare-feu (5) |
| `--key-name cle-lami` | La clé (6) |
| `--wait` | Attend que la VM soit prête avant de rendre la main |
| `vm-cirros` | Le nom de la VM |

(Le routeur, ingrédient 4, est déjà branché sur le réseau privé.)

Résultat : `vm-cirros` est **ACTIVE**, avec l'adresse **`10.10.10.91`**, donnée par le DHCP de Neutron ✅

📸 *Capture 36*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/36-instance-cirros-active.png)

### 11.9 Donner une IP flottante à la VM

:::success
💡 **Pourquoi ?**
`10.10.10.91` n'existe **qu'à l'intérieur** du cloud : Windows ne peut pas la joindre. On lui ajoute donc une IP flottante (voir §3.8).
:::

🐧 **Ubuntu** :
```bash
FIP=$(openstack floating ip create public -f value -c floating_ip_address)
openstack server add floating ip vm-cirros $FIP
openstack server list
```
- **Ligne 1** :
  - `openstack floating ip create public` réserve une IP flottante dans le pool du réseau `public`.
  - `-f value -c floating_ip_address` n'affiche **que** l'adresse, sans tableau.
  - `FIP=$( … )` range ce résultat dans une **variable** nommée `FIP`, une petite boîte qui garde l'adresse en mémoire.
- **Ligne 2** : accroche l'IP flottante (`$FIP` = le contenu de la boîte) à la VM.
- **Ligne 3** : vérifie le résultat.

Résultat : `private=10.10.10.91, 192.168.190.105` ✅ La VM a maintenant **deux** adresses.

📸 *Capture 37*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/37-ip-flottante.png)

### 11.10 Test 1 : pinguer la VM depuis Windows

🪟 **Windows** :
```powershell
ping 192.168.190.105
```
Résultat : **4/4 réponses, 0 % de perte** ✅

:::info
📖 **C'est quoi le TTL ?**
*Time To Live*, la « durée de vie ». C'est un compteur dans chaque paquet. **Chaque routeur traversé enlève 1.**
- En pinguant le routeur directement, on obtient **TTL = 64**.
- En pinguant la VM, on obtient **TTL = 63**.
:::

Ça **prouve** que le paquet a traversé **un routeur** : `router1`, qui a fait la traduction .105 → 10.10.10.91.

📸 *Capture 38*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/38-ping-vm-depuis-windows.png)

### 11.11 Test 2 : se connecter en SSH à la VM depuis Windows

Windows a besoin de la clé **privée**, qui se trouve sur Ubuntu. On la copie avec `scp`.

:::info
📖 **C'est quoi scp ?**
*Secure Copy*. C'est un **copier-coller de fichier** entre deux machines, à travers SSH.
:::

🪟 **Windows** :
```powershell
scp lami@192.168.190.10:.ssh/openstack_key $HOME\.ssh\openstack_key
ssh -i $HOME\.ssh\openstack_key cirros@192.168.190.105
```
- `scp source destination` : copie la clé depuis Ubuntu (`lami@192.168.190.10:.ssh/openstack_key`) vers le dossier `.ssh` de Windows. `$HOME` = `C:\Users\Lami`.
- `ssh -i <clé> cirros@192.168.190.105` : se connecte à la VM avec l'utilisateur `cirros`, en utilisant (`-i`, *identity*) la clé privée.

On arrive sur l'invite 📦 **Cirros** `$`. On tape :
```bash
ip a
```
**Ce qu'on voit, et ce que ça prouve :**
- La carte `eth0` a **seulement** l'adresse `10.10.10.91/24`. La VM **ne connaît pas** son IP flottante .105 : c'est bien le routeur qui fait la traduction (NAT 1:1). ✅
- `mtu 1450` au lieu de 1500 : le réseau privé est transporté dans un « tunnel » (VXLAN) qui prend un peu de place dans chaque paquet.
- La connexion s'est faite **sans mot de passe**, grâce à la clé ✅

📸 *Capture 39*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/39-ssh-vm-cirros-depuis-windows.png)

### 11.12 Test 3 : la VM peut-elle aller sur Internet ?

📦 **Cirros** (toujours connecté à la VM) :
```bash
ping -c 3 8.8.8.8
```
`8.8.8.8` est le serveur DNS de Google, toujours joignable. `-c 3` = envoie seulement 3 pings.

Résultat : `3 received, 0% packet loss` ✅
💡 Le trajet est : VM → routeur OpenStack (**SNAT**) → NAT de VMware → Internet. Le cloud fonctionne **dans les deux sens**.

On quitte la VM avec `exit`.

📸 *Capture 40*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/40-vm-cirros-acces-internet.png)

### 11.13 Test 4 : le site web Horizon

Horizon est accessible depuis le navigateur de Windows, à l'adresse de la VIP : **http://192.168.190.11**
- Domaine : `default`
- Utilisateur : `admin`
- Mot de passe : la valeur de `keystone_admin_password`, lue sur Ubuntu avec `grep keystone_admin_password /etc/kolla/passwords.yml`

:::danger
🔒 **Secret :** ce mot de passe n'apparaît dans **aucune** capture et n'est écrit nulle part dans ce document.
:::

Dans *Projet → Compute → Instances*, on retrouve `vm-cirros` : **Active**, avec ses deux adresses, le gabarit `m1.tiny` et la clé `cle-lami`. **Tout ce qu'on a fait en ligne de commande est visible dans le site web.** Ce sont deux façons de piloter le même cloud.

📸 *Capture 41*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/41-horizon-instances.png)

Dans *Projet → Réseau → Topologie du réseau*, on voit le schéma de toute l'architecture : `public` ↔ `router1` ↔ `private` ↔ `vm-cirros`.

📸 *Capture 42*
![](https://raw.githubusercontent.com/L4ami/tp-openstack-kolla-aio/main/captures/42-horizon-topologie-reseau.png)

### 11.14 Bilan des tests

| Test | Résultat | Ce que ça prouve |
|---|---|---|
| VM démarrée | ✅ `ACTIVE` | Nova, Glance, Placement et QEMU fonctionnent |
| IP privée reçue | ✅ `10.10.10.91` | Le DHCP de Neutron fonctionne |
| Ping du routeur depuis Windows | ✅ | Le lien `ens34` / `br-ex` / réseau externe fonctionne |
| Ping de la VM depuis Windows | ✅ TTL 63 | L'IP flottante (DNAT) et le pare-feu fonctionnent |
| SSH depuis Windows | ✅ | La clé a bien été injectée (Metadata) et le port 22 est ouvert |
| VM vers Internet | ✅ | Le SNAT du routeur fonctionne |
| Horizon | ✅ | La VIP, HAProxy et le site web fonctionnent |

---

## 12. Problèmes rencontrés et solutions

### 12.1 Le démarrage d'Ubuntu restait bloqué environ 2 minutes

- **Ce qu'on voyait :** au démarrage, la ligne `Job systemd-networkd-wait-online.service/start running` restait affichée environ 2 minutes.
- **Pourquoi :** ce service attend que **toutes** les cartes réseau soient « connectées ». Or `ens34` n'a volontairement pas d'IP, donc elle n'est **jamais** considérée comme connectée, et le service attend jusqu'à l'abandon.
- **Solution :** ajouter `optional: true` pour `ens34` dans `/etc/netplan/60-ens34.yaml`, ce qui veut dire « n'attends pas cette carte ».

### 12.2 Les prechecks échouaient : `No module named 'docker'`

- **Ce qu'on voyait :**
  ```
  TASK [prechecks : Checking docker SDK version]
  fatal: [localhost]: FAILED! … ModuleNotFoundError: No module named 'docker'
  ```
- **Pourquoi :** `bootstrap-servers` avait installé le module Python `docker` dans le **Python d'Ubuntu**. Mais Ansible tourne avec le Python du **venv**, qui est **isolé** et ne voit pas ce module. C'est l'inconvénient du venv : chaque boîte à outils est séparée.
- **Solution :** installer les modules **dans le venv** (avec `(kolla-venv)` actif) :
  ```bash
  sudo apt install -y pkg-config libdbus-1-dev libglib2.0-dev
  pip install docker dbus-python
  ```
  (La première ligne installe les outils système nécessaires pour compiler `dbus-python`.)

### 12.3 Impossible de taper `/` dans l'installateur d'Ubuntu

- **Pourquoi :** la disposition de clavier choisie ne correspondait pas au clavier physique (suisse QWERTZ). Les touches étaient donc décalées.
- **Solution :** choisir *Switzerland – French* à l'écran *Keyboard configuration*. Sur ce clavier, `/` = **Maj + 7**.

---

## 13. Différences avec le guide du formateur

| Dans le guide | Dans ce TP | Pourquoi |
|---|---|---|
| `nova_compute_virt_type: "kvm"` | `"qemu"` | Pas de VT-x dans la VM (`vmx = 0`), voir §2.8 |
| `kolla_install_type: "binary"` | supprimé | Cette option n'existe plus dans les versions récentes de Kolla |
| Cartes `ens160` / `ens192` | `ens33` / `ens34` | Ce sont les vrais noms des cartes dans ma VM |
| VIP `192.168.100.250` | `192.168.190.11` | Adaptée à mon réseau VMnet8 |
| (rien) | Fichier netplan pour `ens34` | Pour que la carte soit active sans IP, et ne bloque pas le démarrage |
| (rien) | `pip install docker dbus-python` | Correction de l'erreur des prechecks |

---

## 14. Sécurité : ce qu'on ne publie jamais

| Fichier ou information | Ce qu'il contient | Pourquoi c'est dangereux de le publier |
|---|---|---|
| `/etc/kolla/passwords.yml` | **Tous** les mots de passe du cloud | N'importe qui pourrait prendre le contrôle de tout OpenStack |
| `/etc/kolla/admin-openrc.sh` | Les identifiants de l'admin | Accès administrateur complet |
| `/etc/kolla/clouds.yaml` | Les identifiants de l'admin | Idem |
| Clé privée `openstack_key` | La « clé de la porte » des VM | Accès à toutes les VM qui ont la clé publique |
| Mots de passe Ubuntu et Horizon | | Accès direct |

Dans le dépôt GitHub, un fichier **`.gitignore`** empêche ces fichiers d'être envoyés par erreur.

:::info
📖 **C'est quoi un `.gitignore` ?**
Une liste de fichiers que **Git doit ignorer** : il ne les enverra jamais sur GitHub.
:::

---

## 15. Glossaire

| Mot | Définition simple |
|---|---|
| **AIO (All-in-One)** | Tout OpenStack sur une seule machine |
| **Ansible** | Outil qui automatise des tâches à partir d'une « recette » (*playbook*) |
| **API** | Une « porte d'entrée » pour piloter un logiciel avec des commandes ou des programmes |
| **br-ex** | Switch virtuel Open vSwitch relié à `ens34`, appelé `physnet1` dans Neutron |
| **Cirros** | Linux minuscule fait pour tester un cloud |
| **Conteneur** | Boîte isolée qui contient un programme et tout ce dont il a besoin |
| **DHCP** | Service qui distribue automatiquement les adresses IP |
| **DNS** | Annuaire qui traduit un nom en adresse IP |
| **Docker** | Logiciel qui crée et lance des conteneurs |
| **Egress / Ingress** | Trafic sortant / trafic entrant |
| **Flavor (gabarit)** | Taille d'une VM : CPU, RAM, disque |
| **Glance** | Service des images |
| **HAProxy** | Répartiteur qui porte la VIP et redirige vers les services |
| **Horizon** | Site web d'OpenStack |
| **Hyperviseur** | Logiciel qui fait tourner des VM |
| **IaaS** | Cloud qui fournit des VM, des réseaux et du stockage |
| **ICMP** | Protocole du `ping` |
| **Image** | Disque modèle pour créer une VM |
| **Instance** | Une VM dans OpenStack |
| **Inventaire** | Liste des machines pour Ansible |
| **IP flottante** | Adresse externe redirigée vers l'IP privée d'une VM |
| **Keystone** | Service d'identité (connexion, jetons) |
| **KVM** | Virtualisation rapide qui utilise VT-x |
| **NAT / SNAT / DNAT** | Traduction d'adresse : pour sortir (SNAT) ou pour entrer (DNAT) |
| **Neutron** | Service réseau |
| **Nova** | Service qui gère les VM |
| **Open vSwitch** | Switch réseau virtuel (logiciel) |
| **Paire de clés** | Clé publique (cadenas) + clé privée (clé secrète) |
| **Placement** | Inventaire des ressources libres |
| **Port** | Numéro de « porte » d'un service (22 = SSH) |
| **QEMU** | Émulateur : fait tourner des VM sans VT-x, mais lentement |
| **Routeur** | Relie deux réseaux |
| **Groupe de sécurité** | Pare-feu attaché à une VM |
| **Snapshot** | Photo de la VM pour revenir en arrière |
| **SSH** | Connexion à distance sécurisée en ligne de commande |
| **sudo** | Exécuter une commande en administrateur |
| **tmux** | Garde un terminal vivant même si SSH coupe |
| **TTL** | Compteur qui baisse de 1 à chaque routeur traversé |
| **venv** | Environnement Python isolé |
| **VIP** | Adresse IP virtuelle, point d'entrée unique |
| **VMnet8** | Réseau NAT virtuel de VMware |
| **VT-x** | Fonction du processeur Intel qui accélère la virtualisation |
| **YAML** | Format de fichier texte lisible, sensible aux espaces |

---

## 16. Résumé de révision et conclusion

### 🧠 Les 10 choses à savoir par cœur

1. **OpenStack** transforme des serveurs en **cloud privé IaaS**. C'est une couche **au-dessus** de l'hyperviseur.
2. Les services principaux :
   - **Keystone** (identité) ;
   - **Nova** (VM) ;
   - **Neutron** (réseau) ;
   - **Glance** (images) ;
   - **Placement** (ressources) ;
   - **Horizon** (site web).
3. **Kolla-Ansible** = OpenStack dans des **conteneurs Docker** (Kolla), installé automatiquement par **Ansible**.
4. Les 4 commandes du déploiement, dans l'ordre :
   1. **bootstrap-servers** ;
   2. **prechecks** ;
   3. **deploy** ;
   4. **post-deploy**.
5. **Ubuntu 24.04**, parce que c'est la version supportée par OpenStack 2025.2. On ne lance **jamais** `do-release-upgrade`.
6. Pas de **VT-x** dans la VM, donc pas de KVM, donc **QEMU**.
7. **Deux cartes réseau** : `ens33` pour l'administration (avec IP), `ens34` pour Neutron (**sans IP**).
8. Pour une VM, il faut :
   - une image ;
   - un gabarit ;
   - un réseau ;
   - un routeur ;
   - un groupe de sécurité ;
   - une clé.
9. L'**IP flottante** = un NAT 1:1 fait par le routeur. La VM ne la connaît pas.
10. On ne publie **jamais** `passwords.yml`, `admin-openrc.sh`, `clouds.yaml`, ni les clés privées.

### Conclusion

Le déploiement d'un cloud **OpenStack 2025.2** complet sur une seule VM est **réussi**. Le déploiement lui-même n'a pris qu'une douzaine de minutes. L'essentiel du travail a été la **préparation** : choisir les bonnes versions, préparer le réseau, isoler Python dans un venv.

Ce TP montre bien la différence avec le TP ESXi : ESXi fait tourner des VM, alors qu'OpenStack apporte tout ce qui fait un **cloud** :
- le libre-service ;
- les projets ;
- les images ;
- les réseaux virtuels avec routeurs, NAT, DHCP et pare-feu ;
- une API et un site web.

**Limites, et ce qu'on ferait en entreprise :**
- L'All-in-One n'a **aucune tolérance aux pannes** : si la machine tombe, tout tombe. C'est un environnement d'apprentissage.
- En production, on utiliserait :
  - **plusieurs serveurs** (3 contrôleurs, des serveurs compute, un serveur réseau) ;
  - **KVM** sur de vrais serveurs physiques ;
  - du **stockage persistant** avec Cinder, par exemple sur Ceph ;
  - du **HTTPS (TLS)** sur les API ;
  - de la **supervision**.

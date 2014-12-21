Vue d'ensemble du projet
========================

Le but du projet est de générer du code cryptographique automatiquement.

Voici comment il est découpé:

 * Les algorimtes cryptographiques sont décrits en dans un langage
 haut niveau, le "bbox" ("extension" du langage Julia), à l'aide d'objets et
 de fonctions prédéfinis qui permettent de manipuler des "boîtes" qui
 fonctionnent comme des composants d'électronique numérique : des bits en 
 entrée, un transformation, des bits en sortie. Le fichier aes.jl donne
 un exemple d'utilisation de ce langage.

 * Ce langage de boîtes est ensuite parsé vers un langage très simple, 
 constitué uniquement d'affectations, d'accès à un tableau, de création de 
 variables, et d'opérations binaires ; j'ai appelé ce langage 
 "simplelanguage", abrégé SL par la suite.

 * Le SL est ensuite parsé vers le langage choisi. Pour l'instant, seule
 la compilation vers Python est effectuée (langage ne limitant pas la taille
 des entiers, ce qui est donc plus facile qu'en C).

BBoxlib
=======

La "bboxlib" est une bibliothèque permettant de manipuler des fonctions
booléennes, écrite à des fins de génération automatique de code cryptographique.

L'utilisateur peut créer différentes "boites" et les emboîter. Chaque boîte
possède une taille d'entrée et une taille de sortie. Les deux opérations que 
l'on peut réaliser avec deux boîtes B1 et B2 sont les suivantes :

 * Enchainement :  noté `B1 >> B2` : on exécute d'abord la boite `B1` puis la `B2`.
 La taille de sortie de `B1` doit être la même que la taille d'entrée de `B2`. 
 La bibliothèque fournit également la notation `B2 << B1`, équivalente à la 
 précédente.
 
 * Concaténation : notée `B1 + B2` : on exécute les deux boîtes en parallèle. Les
 tailles d'entrée de `B1` et `B2` doivent être identiques, la taille de sortie
 de `B1 + B2` est la somme des tailles de sortie de `B1` et de `B2`.
 
Types de boîtes disponibles (la signature des fonctions est donnée "à la Julia",
i.e. `f(a::T)` indique que la fonction prend un argument `a` de type `T`):

 * `Slice(a::int, b::int) [assert(b>=a>0)]` :  permet de sélectionner uniquement 
 les bits de `a` à `b` de la boîte sur laquelle le slice va être branché.
 La taille de sortie est `b-a+1`. À la création du slice, on ne sait pas sur
 quelle boîte il va être branché, la taille d'entrée est donc inconnue ; elle
 est donc représentée par une valeur spéciale `Joker`, qui sera remplacée dès
 qu'on branchera une boîte à l'entrée du slice. La taille de sortie de cette boîte
 devra être d'au moins `b`.
 
Les autres types posent moins de surprises:
 
 
 * `SBox(tab::Vector{BitVector})` : SBox, la ta taille d'entrée est log_2(size(tab)) 
 (la taille du tableau doit être une puissance de 2), la taille de la sortie
 est la taille des éléments de tab (tous les éléments de tab doivent avoir
 la même taille).
 
 * `UnOp(func::BoolFunc)` : La taille d'entrée/sortie est celle de 
 la taille de sortie de func. Fonctions disponibles : UXOR, UAddMod, UMulMod.
 
 * `BinOp(s::Int)` : donne s bits en sortie et prend n=k*s bits
 `a_1, ..., a_{ks}` en entrée, la sortie est 
 `(a_1, ..., a_s) op (a_{s+1}, ..., a_{2s}) op ... op (a_{(k-1)s+1}, ..., a_{ks})`. 
 Fonctions disponibles : BXOR, BAddMod, BMulMod. Comme à la construction, on ne
 peut pas déterminer la taille d'entrée, celle-ci est `Joker`.
 
 * `Const(c::BitVector)` : la taille de sortie est la taille du tableau, la 
 taille d'entrée est 0. Représente une constante (a priori à brancher sur
 un `BinOp`).
 
 * `Input(s::Int, name::String)` : représente une entrée du circuit de
 taille s (la sortie est de taille s, l'entrée de taille 0). Peut être utilisé
 par exemple pour passer le message ou une clef en argument du circuit.
 
 * `Perm(n=1::Int, tab::Vector{Int})` : taille d'entrée/sortie : 
 `s*size(tab)`. Effectue une permutation par bloc de `n` bits. Le bloc de bits
 d'entrée n° `i` sera branché sur le bloc de bit de sortie `tab[i]`.
 `PermBytes(t)` est un raccourci pour `Perm(1,t)`.

 * `Map(func::BoolFunc, s::Int)` : donne `s` bits en sortie en dupliquant
 la boîte `func` autant de fois que nécessaire (la taille de sortie de `func`
 doit être un multiple de `s`). La taille d'entrée à la construction est 
 `Joker`.
 
 * `BFMatrix(mat::Matrix{BoolFunc}, law::BinOp)` : simule une matrice, en
 interprêtant les bits d'entrée comme un vecteur dont les composantes sont
 des groupes de bits de taille fixée par les tailles d'entrée des blocs de mat.
 Les blocs de mat sont à l'origine prévus pour être des SBox mais peuvent
 être de n'importe quel type à condition que le type d'entrée de chaque bloc
 ne soit pas `Joker` et que sur chaque ligne, les tailles d'entrée/sortie de 
 des différents blocs sont les mêmes. Le paramètre `law` sert à préciser quelle
 loi on utilise pour associer les réponses des différents blocs ; si on 
 travaille dans un GF(2^n), `law` sera `BXOR`.
 
Il est à noter que ce "langage" est juste constitué d'objets et de functions
écrites en Julia. Ainsi, il est possible d'utiliser toutes les fonctionnalités
de Julia : création de fonction, utilisation de boucle, ... D'ailleurs, 
les fonctions `Map, BFMatrix` et `Perm` ne font que renvoyer des assemblages
des objets précédents.

On peut évaluer le circuit bbox `func` grâce à la commande
`BFeval(func::BoolFunc, ctxt::Dict{String, BitVector})`. Le paramètre 
`ctxt` est le contexte : à chaque nom d'un `Input` doit être associée une
valeur.

Simple Language (SL)
====================

Écriture d'un programme en SL
-----------------------------
Il s'agit d'un module Julia qui peut être indépendamment du projet. Son but est
de pouvoir générer du code réalisant la même action dans plusieurs langages
différents (actuellement, la compilation vers Python ou Java sont implémentées).
Il n'est pas Turing complet, son pouvoir d'expression est limité par 
l'évaluation d'opérations arithmétiques et "bits à bits" sur des entiers de 
taille arbitraire.

Il y a deux notions importantes:

 * Les *expressions* sont constituées 
   - soit d'une variable (type  `Variable`),
   - soit d'une opération binaire (types : `XOR, AND, OR, RShift, LShift, Add,
   Mul, Mod`) représentée par  les opérandes gauche et droites qui sont aussi 
   des expressions,
   - soit d'un accès à tableau (type `AccessTable`) représenté par le tableau
   Julia en question et un index qui est une expression.
 
 * Les *instructions* sont peu nombreuses :
   - `Affectation(var::Variable, exp::Expression)`
   - `NewVariable(length::Int)`
   - `NewArgument(length::Int)`
   - `FreeVariable(var::Variable)` (non implémenté pour le moment)
   
Un *programme* est une suite d'instruction. On peut en créer un nouveau 
grâce à `Program()` et y ajouter des instructions grâce à 
`add_instruction!(p::Program, ins::Instruction)`. Un programme possède également
une entrée, une sortie ; toutes ces données sont des variables
de SL. On les définit grâce aux fonctions `set_entry!(p::Program, v::Variable)`
et `set_output!(p::Program, v:: Variable)`.
L'entrée et la sortie ne peuvent être définie qu'une seule fois. 

Le nombre d'arguments n'est pas limité et les arguments sont repérés grâce à 
leur ordre d'insertion : le premier argument ajouté est l'argument 1, etc.

Lors de la compilation, on peut chaîner différents programmes `p1, ..., pn` 
pour créer un seul programme `P` : l'entrée de `P` est celle de `p1`, la sortie
de `P` est celle de `pn`, la sortie de `p1` est l'entrée de `p2`, etc. Le 
nombre d'arguments de `P` est le nombre maximum d'arguments des `pi` ; le 
premier argument de `P` sera passé en paramètre comme premier argument de tous
les `pi` ayant au moins un paramètre, le second argument de `P` sera passé en
paramètre comme second argument à tous les `pi` ayant au moins deux paramètres,
etc.

Pour compiler un chaînage de plusieurs programmes, on peut utiliser la fonction
`compile_<langage>([p1, p2, ..., pn], "nomDuProgrammeRésultat")` (suivant le 
langage choisi, soit une fonction (en Python), soit une classe est créée (en 
Java).

La création de nouvelle variable est un peu délicate, voici un script type:

    nv_ins = NewVariable(50) # on crée l'instruction
    add_instruction!(p, nv_ins) # on ajoute l'instruction de création de variable au programme p
    nv = Variable(nv_ins) # le compilateur aura besoin de l'instruction de création de la nouvelle variable pour lui attribuer un nom.
    add_instruction!(p, Affectation(nv, exp))
   
Compilation de SL et MemoryManager
----------------------------------

L'écriture d'un compilateur de SL vers un autre langage consiste à créer
une fonction de compilation pour chacun des éléments listés précédemment.
Cette fonction prendra au moins deux arguments : l'élément de SL concerné et
un `MemoryManager`. Ce dernier permet de gérer les noms de variables et de 
mémoriser l'ensemble des tables utilisées (il permet en particulier de pouvoir
réutiliser des noms de variable qui ne sont plus utilisées - même si cette 
fontionnalité n'est pas implémentée pour l'instant).

Pour les variables, il faut explicitement demander au MemoryManager de créer un
nom avec la fonction `new_variable!(mm::MemoryManager, len::Int)`.

Pour les tables, il suffit de demander l'index de la table grâce à 
`get_table_index!(mm::MemoryManager, t::Vector)` ; le MemoryManager entretient
en interne un dictionnaire associant un indice à chaque tableau. Si le tableau
est déjà une cle dans le dictionnaire, alors l'indice correspondant est 
retourné, sinon le tableau est rajouté dans le dictionnaire avec un nouvel
indice.

Dans la plupart des cas, les fonctions gérant les variables auront la forme
suivante (remplacer `python` par le nom du langage vers le quel on écrit un
compilateur). Ici les variables dans le code créé seront appelés `v1, v2, ...`:

    function compile_python!(x::Variable, mm::MemoryManager)
        x.ptr._affected != Nothing() || error("variable not initialized")
        "v"string(x.ptr._affected)
    end

    function compile_python!(x::NewVariable, mm::MemoryManager)
        var = new_variable!(mm, x.len)
        x._affected = var
        return ""
    end

    compile_python!(x::Const, mm::MemoryManager) = "0x"hex(x.ptr)

    compile_python!(x::Affectation, mm::MemoryManager) =
        "v"string(x.dest.ptr._affected)"="compile_python!(x.src, mm)

ATTENTION : il faut bien comprendre que le nommage des variables en SL se fait
tardivement. Ce nommage tardif permet de chaîner facilement des programmes SL,
mais en contrepartie, il faut bien faire attention à ne pas compiler une 
variable tant que celle-ci n'a pas été initialisée (nommée). De même, on peut
récupérer la liste des variables et des tables une fois que tout le programme 
est compilé grâce au MemoryManager, mais il faut être attentif à bien avoir 
compilé TOUT le programme (et notamment la sortie du programme) avant de faire 
cela.

Pour les accès à une table, voici la version pour Python (en Python, on accède
au ième élément de la liste `L` grâce à `L[i]`). Les tables seront appelés 
`t1, t2, ...` :

    compile_python!(x::AccessTable, mm::MemoryManager) =
        "t"string(get_table_index!(mm, x.table))"["compile_python!(x.index, mm)"]"
        
Il faut également définir une fonction compilant un programme complet. 
L'implémentation actuelle du compilateur vers Python produit un module avec
les tables déclarées en variables globales, et une fonction pour le programme
avec comme argument l'entrée puis tous les arguments du programme. La fonction
renvoie la valeur de sortie du programme.

Pour Java le code généré respecte la même structure, mais le tout englobé dans
une classe (vive les classes inutiles !).

BBox vers SL
============

Le fichier bboxcompile compile le langage BBox vers du SL. Il suppose que le
circuit BBox compilé possède une boîte Input nommée "Message" qu'il définit
comme l'entrée du programme SL.  La sortie du programme SL sera la valeur de
sortie de la boîte BBox. Les autres boites Input rencontrés sont transformées
en argument SL (pour notre application cryptographique, il ne doit y avoir qu'un
seul argument : la clef).

La compilation se fait grâce à la fonction `compile_sl(x::BoolFunc)`.

(Pour l'instant la fonction `compile_sl` ne fait pas de vérification, elle 
devrait vérifier que le circuit est bien fermé et qu'elle comporte qu'une seule
boîte Input nommée "Message".)

Pour l'instant, le code Python généré s'exécute plus vite que le code Java (sans
même compter le temps de compilation du Java).

Todo list
=========

À faire :
 - Implémenter d'autres algos en Bbox (Jacques pourrait le faire directement,
 cela ne me paraît pas beaucoup plus compliqué que de l'écrire sur papier).
 - Automatiser la chaîne BBox > SL > Java/Python/C avec vérifications des 
 différentes contraintes (voir avec Jean-Philippe ce qu'il veut précisemment)
 - Créer le compilo pour C, LA difficulté étant la gestion des grand entiers,
 je vois plusieurs possibilités :
    * (mode dégueulasse) : utiliser un outil tel cython ou pyrex (le temps de 
    compilation est prohibitif, vu qu'il faut embarquer tout l'interpréteur
    Python).
    * utiliser une lib C gérant les grands entiers (à voir avec JP ce qu'on a le
    droit d'utiliser)
    * se programmer une petite lib qui gère ça et générer la lib à chaque fois
    (pas de problème de dépendances, la lib doit pas être monstrueuse vu qu'on
    ne gère que du 128 bits maxi)
    * faire un truc subtil en compilant le SL de façon intelligente, en prenant
    en compte les tailles de variable ; par exemple, lors qu'une variable SL
    de 128 bits est créée, la compilation créée de façon silencieuse deux 
    entiers non signés C de 64 bits.

Quelques optimisations en vrac :
 - pour le compilo vers Java, on utilise des BigInteger tout le temps, alors
 que la plupart du temps, on manipule des octets, ça ralentit sûrement
 énormément ; si on implémente le dernier point ci-dessus, on peut même éviter
 complètement le recours à BigInteger.
 - le code généré comporte un nombre relativement important d'instructions du 
 genre `(x >> 8) << 8` qui pourraient être simplifiées en `x` ou en `x & 0xff00`
 - lors du parsing de BBox, transformer les `Slice(a,b) + Slice(b+1,c)` en 
 `Slice(a, c)`.

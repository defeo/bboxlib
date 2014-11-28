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
 
Types de boîtes disponibles :

 * `Slice(a::int, b::int) [assert(b>=a>0)]` :  permet de sélectionner uniquement 
 les bits de `a` à `b` de la boîte sur laquelle le slice va être branché.
 La taille de sortie est `b-a+1`. À la création du slice, on ne sait pas sur
 quelle boîte il va être branché, la taille d'entrée est donc inconnue ; elle
 est donc représentée par une valeur spéciale `Joker`, qui sera remplacée dès
 qu'on branche une boîte à l'entrée du slice. La taille de sortie de cette boîte
 devra être d'au moins `b`.
 
Les autres types posent moins de surprises:
 
 * `Perm(Array)`
 
 * `SBox(Array)`
 
 * `Binop(op::Char, arg::Boite | Constante)`

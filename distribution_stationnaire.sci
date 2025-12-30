// ============================================================================
// MINI PROJET: OPTIMISATION DE LA MAINTENANCE D'ÉQUIPEMENTS INDUSTRIELS
// Module: Modélisation Stochastique
// ============================================================================
// Sujet: Modélisation de l'état de machines industrielles par chaînes de 
// Markov et optimisation de la stratégie de maintenance préventive
// ============================================================================


// ============================================================================
// PARTIE 1: ANALYSE DE DONNÉES PRATIQUES
// ============================================================================
disp("============================================================");
disp("PARTIE 1: ANALYSE DES DONNÉES DE MAINTENANCE");
disp("============================================================");

// Génération de données simulées basées sur des observations réelles
// États: 1=Excellent, 2=Bon, 3=Moyen, 4=Dégradé, 5=Défaillant
rand('seed', 123);

// Historique de 100 observations d'états de machines sur 6 mois
n_observations = 100;
etats_observes = [1*ones(1,25), 2*ones(1,30), 3*ones(1,20), ...
                  4*ones(1,15), 5*ones(1,10)];
etats_observes = grand(1, "prm", etats_observes); // Permutation aléatoire

// Calcul des statistiques descriptives
disp("Statistiques des états observés:");
for i = 1:5
    freq = sum(etats_observes == i) / n_observations * 100;
    disp(sprintf("  État %d: %.1f%%", i, freq));
end

// Coûts associés (en milliers d'euros)
cout_maintenance_preventive = 5;   // Coût maintenance préventive
cout_reparation = [0, 2, 8, 15, 50]; // Coût selon état à la défaillance
cout_production_perdue = 20;       // Coût d'arrêt production

disp(" ");
disp("Coûts de maintenance (k€):");
disp(sprintf("  Maintenance préventive: %.0f", cout_maintenance_preventive));
disp(sprintf("  Réparation (défaillance): %.0f", cout_reparation(5)));

// ============================================================================
// PARTIE 2: MODÉLISATION STOCHASTIQUE - CHAÎNE DE MARKOV
// ============================================================================
disp(" ");
disp("============================================================");
disp("PARTIE 2: MODÉLISATION PAR CHAÎNE DE MARKOV");
disp("============================================================");

// Matrice de transition P (sans maintenance préventive)
// P(i,j) = probabilité de passer de l'état i à l'état j
P = [0.70, 0.25, 0.05, 0.00, 0.00;   // État 1 (Excellent)
     0.00, 0.60, 0.30, 0.10, 0.00;   // État 2 (Bon)
     0.00, 0.00, 0.50, 0.35, 0.15;   // État 3 (Moyen)
     0.00, 0.00, 0.00, 0.40, 0.60;   // État 4 (Dégradé)
     0.00, 0.00, 0.00, 0.00, 1.00];  // État 5 (Défaillant - absorbant)

disp("Matrice de transition P:");
disp(P);

// Vérification: somme des lignes = 1
verification = sum(P, 'c');
disp("Vérification (somme lignes = 1):");
disp(verification');

// Calcul de la distribution stationnaire (équilibre)
// Résolution de π*P = π avec Σπᵢ = 1
function [pi_stat] = distribution_stationnaire(P)
    n = size(P, 1);
    A = [P' - eye(n, n); ones(1, n)];
    b = [zeros(n, 1); 1];
    pi_stat = A \ b;
    pi_stat = pi_stat' / sum(pi_stat); // Normalisation
endfunction

// Calcul du temps moyen avant défaillance
function [temps_moyen] = temps_avant_defaillance(P, etat_initial)
    n = size(P, 1);
    Q = P(1:n-1, 1:n-1); // Sous-matrice des états transitoires
    N = inv(eye(n-1, n-1) - Q); // Matrice fondamentale
    t = sum(N, 'c'); // Temps d'absorption moyen
    temps_moyen = t(etat_initial);
endfunction

temps_moy = temps_avant_defaillance(P, 1);
disp(sprintf("Temps moyen avant défaillance (état 1): %.2f périodes", temps_moy));

// ============================================================================
// PARTIE 3: OPTIMISATION DE LA STRATÉGIE DE MAINTENANCE
// ============================================================================
disp(" ");
disp("============================================================");
disp("PARTIE 3: OPTIMISATION PAR ALGORITHME GÉNÉTIQUE");
disp("============================================================");

// Stratégie de maintenance: vecteur binaire [s₂, s₃, s₄]
// sᵢ = 1 si on effectue maintenance préventive à l'état i, 0 sinon
// (On ne considère pas l'état 1 (trop bon) ni l'état 5 (défaillance))

// Fonction objectif: coût total moyen à long terme
function [cout_total] = evaluer_strategie(strategie, P, couts)
    // Modification de la matrice de transition selon la stratégie
    P_modif = P;
    
    // Si maintenance à l'état i, retour à l'état 1
    for i = 2:4
        if strategie(i-1) == 1 then
            P_modif(i, :) = [1, 0, 0, 0, 0]; // Retour à état excellent
        end
    end
    
    // Simulation sur horizon long
    n_simulations = 1000;
    horizon = 50;
    cout_total = 0;
    
    for sim = 1:n_simulations
        etat = 1; // État initial
        cout_simulation = 0;
        
        for t = 1:horizon
            // Coût de maintenance préventive
            if etat >= 2 & etat <= 4 & strategie(etat-1) == 1 then
                cout_simulation = cout_simulation + couts.preventive;
                etat = 1; // Retour à excellent après maintenance
            else
                // Transition normale
                probs = P_modif(etat, :);
                etat_suivant = grand(1, "markov", probs, 1);
                
                // Coût de réparation si défaillance
                if etat_suivant == 5 then
                    cout_simulation = cout_simulation + couts.reparation(etat) + couts.production;
                    etat = 1; // Réparation = retour à excellent
                else
                    etat = etat_suivant;
                end
            end
        end
        
        cout_total = cout_total + cout_simulation / horizon;
    end
    
    cout_total = cout_total / n_simulations;
endfunction

// Structure des coûts
couts = struct('preventive', cout_maintenance_preventive, ...
               'reparation', cout_reparation, ...
               'production', cout_production_perdue);

// Algorithme génétique simple pour optimisation
disp("Recherche de la stratégie optimale...");

taille_population = 20;
n_generations = 30;
taux_mutation = 0.2;

// Initialisation population
population = grand(taille_population, 3, "uin", 0, 1);
meilleurs_couts = zeros(n_generations, 1);

for gen = 1:n_generations
    // Évaluation
    couts_pop = zeros(taille_population, 1);
    for i = 1:taille_population
        couts_pop(i) = evaluer_strategie(population(i, :), P, couts);
    end
    
    // Sélection des meilleurs
    [couts_tries, indices] = gsort(couts_pop, 'g', 'i');
    meilleurs_couts(gen) = couts_tries(1);
    population = population(indices(1:taille_population/2), :);
    
    // Reproduction (croisement)
    nouvelles_strategies = [];
    for i = 1:2:size(population, 1)
        parent1 = population(i, :);
        parent2 = population(min(i+1, size(population, 1)), :);
        point_croisement = grand(1, "uin", 1, 2);
        enfant1 = [parent1(1:point_croisement), parent2(point_croisement+1:$)];
        enfant2 = [parent2(1:point_croisement), parent1(point_croisement+1:$)];
        nouvelles_strategies = [nouvelles_strategies; enfant1; enfant2];
    end
    
    // Mutation
    for i = 1:size(nouvelles_strategies, 1)
        if rand() < taux_mutation then
            pos = grand(1, "uin", 1, 3);
            nouvelles_strategies(i, pos) = 1 - nouvelles_strategies(i, pos);
        end
    end
    
    population = [population; nouvelles_strategies];
end

// Meilleure stratégie trouvée
couts_finaux = zeros(size(population, 1), 1);
for i = 1:size(population, 1)
    couts_finaux(i) = evaluer_strategie(population(i, :), P, couts);
end
[cout_optimal, idx_optimal] = min(couts_finaux);
strategie_optimale = population(idx_optimal, :);

disp(" ");
disp("RÉSULTATS DE LOPTIMISATION:");
disp(sprintf("Stratégie optimale: [%d, %d, %d]", strategie_optimale(1), ...
             strategie_optimale(2), strategie_optimale(3)));
disp(sprintf("  État 2 (Bon): %s", iif(strategie_optimale(1)==1, "Maintenance", "Attente")));
disp(sprintf("  État 3 (Moyen): %s", iif(strategie_optimale(2)==1, "Maintenance", "Attente")));
disp(sprintf("  État 4 (Dégradé): %s", iif(strategie_optimale(3)==1, "Maintenance", "Attente")));
disp(sprintf("Coût moyen optimal: %.2f k€/période", cout_optimal));

// Comparaison avec stratégie sans maintenance
cout_sans_maintenance = evaluer_strategie([0, 0, 0], P, couts);
disp(sprintf("Coût sans maintenance: %.2f k€/période", cout_sans_maintenance));
disp(sprintf("Économie réalisée: %.2f k€/période (%.1f%%)", ...
             cout_sans_maintenance - cout_optimal, ...
             (cout_sans_maintenance - cout_optimal)/cout_sans_maintenance*100));

// ============================================================================
// PARTIE 4: VISUALISATION
// ============================================================================
disp(" ");
disp("Génération des graphiques...");

// Graphique 1: Convergence de l'algorithme génétique
scf(1);
plot(1:n_generations, meilleurs_couts, 'b-', 'LineWidth', 2);
xlabel('Génération', 'fontsize', 3);
ylabel('Coût minimal (k€)', 'fontsize', 3);
title('Convergence de l''algorithme génétique', 'fontsize', 4);
xgrid();

// Graphique 2: Simulation d'une trajectoire avec stratégie optimale
scf(2);
P_optimal = P;
for i = 2:4
    if strategie_optimale(i-1) == 1 then
        P_optimal(i, :) = [1, 0, 0, 0, 0];
    end
end

etat = 1;
trajectoire = zeros(1, 100);
for t = 1:100
    trajectoire(t) = etat;
    if etat >= 2 & etat <= 4 & strategie_optimale(etat-1) == 1 then
        etat = 1;
    else
        probs = P_optimal(etat, :);
        etat = grand(1, "markov", probs, 1);
        if etat == 5 then
            etat = 1; // Réparation
        end
    end
end

plot(1:100, trajectoire, 'r-o', 'MarkerSize', 4);
xlabel('Temps (périodes)', 'fontsize', 3);
ylabel('État de la machine', 'fontsize', 3);
title('Simulation de trajectoire avec stratégie optimale', 'fontsize', 4);
yticks([1:5]);
yticklabels(["Excellent", "Bon", "Moyen", "Dégradé", "Défaillant"]);
xgrid();

// Graphique 3: Comparaison des coûts selon différentes stratégies
scf(3);
strategies_test = [
    [0, 0, 0];  // Aucune maintenance
    [0, 0, 1];  // Maintenance état 4
    [0, 1, 1];  // Maintenance états 3-4
    [1, 1, 1];  // Maintenance tous états
    strategie_optimale  // Stratégie optimale
];

couts_strategies = zeros(5, 1);
for i = 1:5
    couts_strategies(i) = evaluer_strategie(strategies_test(i, :), P, couts);
end

bar(1:5, couts_strategies);
xlabel('Stratégie', 'fontsize', 3);
ylabel('Coût moyen (k€)', 'fontsize', 3);
title('Comparaison des coûts par stratégie', 'fontsize', 4);
xticklabels(["Aucune", "État 4", "États 3-4", "Tous", "Optimale"]);
xgrid();

disp(" ");
disp("============================================================");
disp("ANALYSE TERMINÉE - Graphiques affichés");
disp("============================================================");


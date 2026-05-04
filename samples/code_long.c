/*
 * complex.c — Tas de trucs compliqués mélangés ensemble :
 *   - Allocateur mémoire maison (pool allocator)
 *   - Table de hachage générique
 *   - Arbre AVL
 *   - Chiffrement XOR en flux (stream cipher basique)
 *   - Transformée de Fourier discrète naïve (DFT)
 *   - Générateur de nombres pseudo-aléatoires (xorshift64)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <assert.h>

/* ================================================================
 * 1. POOL ALLOCATOR
 * ================================================================ */

#define POOL_SIZE (1024 * 1024)  /* 1 Mo */

typedef struct {
    uint8_t  memory[POOL_SIZE];
    size_t   offset;
    size_t   peak;
} MemPool;

static MemPool g_pool;

void pool_init(void) {
    memset(&g_pool, 0, sizeof(g_pool));
}

void *pool_alloc(size_t size) {
    size = (size + 7) & ~(size_t)7;  /* alignement 8 octets */
    if (g_pool.offset + size > POOL_SIZE) {
        fprintf(stderr, "[pool] OOM: demande %zu, dispo %zu\n",
                size, POOL_SIZE - g_pool.offset);
        return NULL;
    }
    void *ptr = g_pool.memory + g_pool.offset;
    g_pool.offset += size;
    if (g_pool.offset > g_pool.peak) g_pool.peak = g_pool.offset;
    return ptr;
}

void pool_reset(void) {
    g_pool.offset = 0;
}

void pool_stats(void) {
    printf("[pool] utilisé=%zu pic=%zu capacité=%d\n",
           g_pool.offset, g_pool.peak, POOL_SIZE);
}

/* ================================================================
 * 2. XORSHIFT64 — PRNG
 * ================================================================ */

static uint64_t xr_state = 0xdeadbeefcafebabe;

uint64_t xorshift64(void) {
    xr_state ^= xr_state << 13;
    xr_state ^= xr_state >> 7;
    xr_state ^= xr_state << 17;
    return xr_state;
}

double rand_double(void) {
    return (double)(xorshift64() >> 11) / (double)(UINT64_C(1) << 53);
}

/* ================================================================
 * 3. TABLE DE HACHAGE (open addressing, Robin Hood hashing)
 * ================================================================ */

#define HT_INITIAL_CAP 16

typedef struct {
    char    *key;
    int64_t  value;
    int      dist;   /* distance de sondage (Robin Hood) */
} HTEntry;

typedef struct {
    HTEntry *entries;
    size_t   cap;
    size_t   count;
} HashTable;

static uint64_t ht_hash(const char *key) {
    uint64_t h = 14695981039346656037ULL;  /* FNV-1a 64 bits */
    while (*key) {
        h ^= (uint8_t)*key++;
        h *= 1099511628211ULL;
    }
    return h;
}

HashTable *ht_create(void) {
    HashTable *ht = pool_alloc(sizeof(HashTable));
    ht->cap     = HT_INITIAL_CAP;
    ht->count   = 0;
    ht->entries = pool_alloc(sizeof(HTEntry) * ht->cap);
    memset(ht->entries, 0, sizeof(HTEntry) * ht->cap);
    return ht;
}

static void ht_insert_raw(HashTable *ht, char *key, int64_t value, int dist) {
    size_t idx = ht_hash(key) & (ht->cap - 1);
    for (;;) {
        HTEntry *e = &ht->entries[idx];
        if (!e->key) {
            e->key   = key;
            e->value = value;
            e->dist  = dist;
            ht->count++;
            return;
        }
        if (strcmp(e->key, key) == 0) {
            e->value = value;
            return;
        }
        /* Robin Hood : on vole à celui qui est plus riche */
        if (e->dist < dist) {
            char    *tk = e->key;   e->key   = key;   key   = tk;
            int64_t  tv = e->value; e->value = value; value = tv;
            int      td = e->dist;  e->dist  = dist;  dist  = td;
        }
        dist++;
        idx = (idx + 1) & (ht->cap - 1);
    }
}

void ht_set(HashTable *ht, const char *key, int64_t value) {
    /* copie de la clé dans le pool */
    size_t klen = strlen(key) + 1;
    char  *kdup = pool_alloc(klen);
    memcpy(kdup, key, klen);
    ht_insert_raw(ht, kdup, value, 0);
}

int ht_get(HashTable *ht, const char *key, int64_t *out) {
    size_t idx = ht_hash(key) & (ht->cap - 1);
    int    dist = 0;
    while (ht->entries[idx].key && ht->entries[idx].dist >= dist) {
        if (strcmp(ht->entries[idx].key, key) == 0) {
            *out = ht->entries[idx].value;
            return 1;
        }
        idx = (idx + 1) & (ht->cap - 1);
        dist++;
    }
    return 0;
}

void ht_dump(HashTable *ht) {
    printf("[hashtable] count=%zu cap=%zu\n", ht->count, ht->cap);
    for (size_t i = 0; i < ht->cap; i++) {
        if (ht->entries[i].key)
            printf("  [%zu] \"%s\" => %lld (dist=%d)\n",
                   i, ht->entries[i].key,
                   (long long)ht->entries[i].value,
                   ht->entries[i].dist);
    }
}

/* ================================================================
 * 4. ARBRE AVL
 * ================================================================ */

typedef struct AVLNode {
    int            key;
    int            height;
    struct AVLNode *left, *right;
} AVLNode;

static int avl_height(AVLNode *n) {
    return n ? n->height : 0;
}

static int avl_bf(AVLNode *n) {
    return avl_height(n->left) - avl_height(n->right);
}

static void avl_update_height(AVLNode *n) {
    int lh = avl_height(n->left);
    int rh = avl_height(n->right);
    n->height = 1 + (lh > rh ? lh : rh);
}

static AVLNode *avl_new(int key) {
    AVLNode *n = pool_alloc(sizeof(AVLNode));
    n->key    = key;
    n->height = 1;
    n->left   = n->right = NULL;
    return n;
}

static AVLNode *avl_rot_right(AVLNode *y) {
    AVLNode *x = y->left, *T2 = x->right;
    x->right = y; y->left = T2;
    avl_update_height(y);
    avl_update_height(x);
    return x;
}

static AVLNode *avl_rot_left(AVLNode *x) {
    AVLNode *y = x->right, *T2 = y->left;
    y->left = x; x->right = T2;
    avl_update_height(x);
    avl_update_height(y);
    return y;
}

AVLNode *avl_insert(AVLNode *root, int key) {
    if (!root) return avl_new(key);
    if (key < root->key)       root->left  = avl_insert(root->left,  key);
    else if (key > root->key)  root->right = avl_insert(root->right, key);
    else return root;  /* doublon */

    avl_update_height(root);
    int bf = avl_bf(root);

    if (bf > 1 && key < root->left->key)             return avl_rot_right(root);
    if (bf < -1 && key > root->right->key)            return avl_rot_left(root);
    if (bf > 1 && key > root->left->key) {
        root->left = avl_rot_left(root->left);
        return avl_rot_right(root);
    }
    if (bf < -1 && key < root->right->key) {
        root->right = avl_rot_right(root->right);
        return avl_rot_left(root);
    }
    return root;
}

void avl_inorder(AVLNode *root, int *buf, int *idx) {
    if (!root) return;
    avl_inorder(root->left,  buf, idx);
    buf[(*idx)++] = root->key;
    avl_inorder(root->right, buf, idx);
}

int avl_is_sorted(int *arr, int n) {
    for (int i = 1; i < n; i++)
        if (arr[i] < arr[i-1]) return 0;
    return 1;
}

/* ================================================================
 * 5. CHIFFREMENT XOR EN FLUX (keystream xorshift)
 * ================================================================ */

void xor_encrypt(const uint8_t *in, uint8_t *out, size_t len, uint64_t seed) {
    uint64_t state = seed;
    for (size_t i = 0; i < len; i++) {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        out[i] = in[i] ^ (uint8_t)(state & 0xFF);
    }
}

/* déchiffrement = même opération XOR */
#define xor_decrypt xor_encrypt

/* ================================================================
 * 6. TRANSFORMÉE DE FOURIER DISCRÈTE NAÏVE (O(N²))
 * ================================================================ */

typedef struct { double re, im; } Complex;

static Complex cadd(Complex a, Complex b) { return (Complex){a.re+b.re, a.im+b.im}; }
static Complex cmul(Complex a, Complex b) {
    return (Complex){a.re*b.re - a.im*b.im, a.re*b.im + a.im*b.re};
}

void dft(const Complex *x, Complex *X, int N) {
    for (int k = 0; k < N; k++) {
        X[k] = (Complex){0, 0};
        for (int n = 0; n < N; n++) {
            double angle = -2.0 * M_PI * k * n / N;
            Complex w = { cos(angle), sin(angle) };
            X[k] = cadd(X[k], cmul(x[n], w));
        }
    }
}

double complex_mag(Complex c) {
    return sqrt(c.re*c.re + c.im*c.im);
}

/* ================================================================
 * MAIN — démonstration
 * ================================================================ */

int main(void) {
    pool_init();

    /* --- PRNG --- */
    printf("=== PRNG xorshift64 ===\n");
    for (int i = 0; i < 5; i++)
        printf("  rand[%d] = %.6f\n", i, rand_double());

    /* --- Hash table --- */
    printf("\n=== Hash Table ===\n");
    HashTable *ht = ht_create();
    const char *mots[] = { "alpha", "beta", "gamma", "delta", "epsilon",
                           "zeta", "eta", "theta", "iota", "kappa" };
    for (int i = 0; i < 10; i++) {
        char key[32];
        snprintf(key, sizeof(key), "%s_%d", mots[i], i);
        ht_set(ht, key, (int64_t)(xorshift64() % 1000));
    }
    ht_dump(ht);
    int64_t v;
    if (ht_get(ht, "gamma_2", &v)) printf("  gamma_2 = %lld\n", (long long)v);

    /* --- Arbre AVL --- */
    printf("\n=== Arbre AVL ===\n");
#define N_AVL 20
    int vals[N_AVL];
    AVLNode *root = NULL;
    for (int i = 0; i < N_AVL; i++) {
        vals[i] = (int)(xorshift64() % 200);
        root    = avl_insert(root, vals[i]);
        printf("  insert(%d) -> hauteur=%d\n", vals[i], root->height);
    }
    int sorted[N_AVL]; int idx = 0;
    avl_inorder(root, sorted, &idx);
    printf("  inorder: ");
    for (int i = 0; i < idx; i++) printf("%d ", sorted[i]);
    printf("\n  trié ? %s\n", avl_is_sorted(sorted, idx) ? "OUI" : "NON");

    /* --- Chiffrement XOR --- */
    printf("\n=== Chiffrement XOR flux ===\n");
    const char *msg = "Bonjour monde, ceci est un message secret 42!";
    size_t mlen = strlen(msg);
    uint8_t *cipher = pool_alloc(mlen);
    uint8_t *plain2 = pool_alloc(mlen + 1);
    plain2[mlen] = '\0';

    xor_encrypt((const uint8_t *)msg, cipher, mlen, 0xBADC0FFEE0DDF00D);
    xor_decrypt(cipher, plain2, mlen, 0xBADC0FFEE0DDF00D);

    printf("  original  : %s\n", msg);
    printf("  chiffré   : ");
    for (size_t i = 0; i < mlen; i++) printf("%02X", cipher[i]);
    printf("\n  déchiffré : %s\n", (char *)plain2);
    printf("  intact ? %s\n", memcmp(msg, plain2, mlen) == 0 ? "OUI" : "NON");

    /* --- DFT --- */
    printf("\n=== DFT naïve (N=16) ===\n");
#define N_DFT 16
    Complex signal[N_DFT], spectrum[N_DFT];
    /* signal = cos(2π·2·n/N) + 0.5·cos(2π·5·n/N) */
    for (int n = 0; n < N_DFT; n++) {
        signal[n].re = cos(2*M_PI*2*n/N_DFT) + 0.5*cos(2*M_PI*5*n/N_DFT);
        signal[n].im = 0.0;
    }
    dft(signal, spectrum, N_DFT);
    for (int k = 0; k < N_DFT; k++) {
        double mag = complex_mag(spectrum[k]) / N_DFT;
        printf("  X[%2d] = %6.3f + %6.3fi  |mag|=%.3f%s\n",
               k, spectrum[k].re/N_DFT, spectrum[k].im/N_DFT, mag,
               mag > 0.2 ? "  <-- pic" : "");
    }

    /* --- Stats pool --- */
    printf("\n");
    pool_stats();

    return 0;
}

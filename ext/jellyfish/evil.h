#ifndef EVIL_H

#include "ruby.h"

typedef struct RNode {
    VALUE flags;
    VALUE nd_reserved;		/* ex nd_file */
    union {
        struct RNode *node;
        ID id;
	    VALUE value;
	    VALUE (*cfunc)(ANYARGS);
	    ID *tbl;
    } u1;
    union {
	    struct RNode *node;
	    ID id;
	    long argc;
	    VALUE value;
    } u2;
    union {
	    struct RNode *node;
	    ID id;
	    long state;
	    struct rb_global_entry *entry;
	    long cnt;
	    VALUE value;
    } u3;
} NODE;

struct rb_iseq_struct {
    /***************/
    /* static data */
    /***************/

    enum iseq_type {
        ISEQ_TYPE_TOP,
        ISEQ_TYPE_METHOD,
        ISEQ_TYPE_BLOCK,
        ISEQ_TYPE_CLASS,
        ISEQ_TYPE_RESCUE,
        ISEQ_TYPE_ENSURE,
        ISEQ_TYPE_EVAL,
        ISEQ_TYPE_MAIN,
        ISEQ_TYPE_DEFINED_GUARD
    } type;              /* instruction sequence type */

    VALUE name;	         /* String: iseq name */
    VALUE filename;      /* file information where this sequence from */
    VALUE filepath;      /* real file path or nil */
    VALUE *iseq;         /* iseq (insn number and operands) */
    VALUE *iseq_encoded; /* encoded iseq */
    unsigned long iseq_size;
    VALUE mark_ary;	/* Array: includes operands which should be GC marked */
    VALUE coverage;     /* coverage array */
    unsigned short line_no;

    /* insn info, must be freed */
    struct iseq_insn_info_entry *insn_info_table;
    size_t insn_info_size;

    ID *local_table;		/* must free */
    int local_table_size;

    /* method, class frame: sizeof(vars) + 1, block frame: sizeof(vars) */
    int local_size;

    struct iseq_inline_cache_entry *ic_entries;
    int ic_size;

    /**
     * argument information
     *
     *  def m(a1, a2, ..., aM,                    # mandatory
     *        b1=(...), b2=(...), ..., bN=(...),  # optional
     *        *c,                                 # rest
     *        d1, d2, ..., dO,                    # post
     *        &e)                                 # block
     * =>
     *
     *  argc           = M
     *  arg_rest       = M+N+1 // or -1 if no rest arg
     *  arg_opts       = N+1   // or 0  if no optional arg
     *  arg_opt_table  = [ (arg_opts entries) ]
     *  arg_post_len   = O // 0 if no post arguments
     *  arg_post_start = M+N+2
     *  arg_block      = M+N + 1 + O + 1 // -1 if no block arg
     *  arg_simple     = 0 if not simple arguments.
     *                 = 1 if no opt, rest, post, block.
     *                 = 2 if ambiguous block parameter ({|a|}).
     *  arg_size       = argument size.
     */

    int argc;
    int arg_simple;
    int arg_rest;
    int arg_block;
    int arg_opts;
    int arg_post_len;
    int arg_post_start;
    int arg_size;
    VALUE *arg_opt_table;

    size_t stack_max; /* for stack overflow check */

    /* catch table */
    struct iseq_catch_table_entry *catch_table;
    int catch_table_size;

    /* for child iseq */
    struct rb_iseq_struct *parent_iseq;
    struct rb_iseq_struct *local_iseq;

    /****************/
    /* dynamic data */
    /****************/

    VALUE self;
    VALUE orig;			/* non-NULL if its data have origin */

    /* block inlining */
    /*
     * NODE *node;
     * void *special_block_builder;
     * void *cached_special_block_builder;
     * VALUE cached_special_block;
     */

    /* klass/module nest information stack (cref) */
    NODE *cref_stack;
    VALUE klass;

    /* misc */
    ID defined_method_id;	/* for define_method */

    /* used at compile time */
    struct iseq_compile_data *compile_data;
};

typedef struct rb_iseq_struct rb_iseq_t;

typedef enum {
    VM_METHOD_TYPE_ISEQ,
    VM_METHOD_TYPE_CFUNC,
    VM_METHOD_TYPE_ATTRSET,
    VM_METHOD_TYPE_IVAR,
    VM_METHOD_TYPE_BMETHOD,
    VM_METHOD_TYPE_ZSUPER,
    VM_METHOD_TYPE_UNDEF,
    VM_METHOD_TYPE_NOTIMPLEMENTED,
    VM_METHOD_TYPE_OPTIMIZED, /* Kernel#send, Proc#call, etc */
    VM_METHOD_TYPE_MISSING   /* wrapper for method_missing(id) */
} rb_method_type_t;

typedef struct rb_method_cfunc_struct {
    VALUE (*func)(ANYARGS);
    int argc;
} rb_method_cfunc_t;

typedef struct rb_method_attr_struct {
    ID id;
    VALUE location;
} rb_method_attr_t;

typedef enum {
    NOEX_PUBLIC    = 0x00,
    NOEX_NOSUPER   = 0x01,
    NOEX_PRIVATE   = 0x02,
    NOEX_PROTECTED = 0x04,
    NOEX_MASK      = 0x06,
    NOEX_BASIC     = 0x08,
    NOEX_UNDEF     = NOEX_NOSUPER,
    NOEX_MODFUNC   = 0x12,
    NOEX_SUPER     = 0x20,
    NOEX_VCALL     = 0x40,
    NOEX_RESPONDS  = 0x80
} rb_method_flag_t;

typedef struct rb_method_definition_struct {
    rb_method_type_t type; /* method type */
    ID original_id;
    union {
        rb_iseq_t *iseq;            /* should be mark */
        rb_method_cfunc_t cfunc;
        rb_method_attr_t attr;
        VALUE proc;                 /* should be mark */
        enum method_optimized_type {
            OPTIMIZED_METHOD_TYPE_SEND,
            OPTIMIZED_METHOD_TYPE_CALL
        } optimize_type;
    } body;
    int alias_count;
} rb_method_definition_t;

typedef struct rb_method_entry_struct {
    rb_method_flag_t flag;
    char mark;
    rb_method_definition_t *def;
    ID called_id;
    VALUE klass;                    /* should be mark */
} rb_method_entry_t;

struct METHOD {
    VALUE recv;
    VALUE rclass;
    ID id;
    rb_method_entry_t *me;
    struct unlinked_method_entry_list_entry *ume;
};

#define GetCoreDataFromValue(obj, type, ptr) do { \
    (ptr) = (type*)DATA_PTR(obj); \
} while (0)

#define GetISeqPtr(obj, ptr) \
  GetCoreDataFromValue((obj), rb_iseq_t, (ptr))

#endif
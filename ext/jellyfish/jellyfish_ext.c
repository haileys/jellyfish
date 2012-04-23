#include <stdlib.h>
#include "ruby.h"
#include "evil.h"

static VALUE mJellyfish;
extern VALUE rb_cISeq;

rb_iseq_t* rb_method_get_iseq(VALUE method);

static VALUE iseq_for_method(VALUE self, VALUE meth)
{
    VALUE obj = Qnil;
    rb_iseq_t* iseq;
    
    if(rb_obj_is_method(meth)) {
        iseq = rb_method_get_iseq(meth);
        obj = rb_obj_alloc(rb_cISeq);
        DATA_PTR(obj) = iseq;
        return obj;
    } else {
        return Qnil;
    }
}

void Init_banana_ext()
{
    mJellyfish = rb_define_module("Jellyfish");
    rb_define_singleton_method(mJellyfish, "iseq_for_method", iseq_for_method, 1);
}
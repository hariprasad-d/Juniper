set args -N
#source /homes/hprasad/l2ald.gdb.macs

#
# hbt tree
#
define hbt_find_leftmost
    set $XXnode = $arg0
    set $XXnext = (hbt_node_t *)($XXnode->hbt_data[0] & ~0x3)
    while $XXnext
        set $XXnode = $XXnext
        set $XXnext = (hbt_node_t *)($XXnode->hbt_data[0] & ~0x3)
    end
end

define hbt_iterate_next
    set $Xroot = (hbt_node_t *) $arg0
    set $Xnode = (hbt_node_t *) $arg1

    if !$Xnode
        if !$Xroot
            set $Xnode = 0
        else
            hbt_find_leftmost $Xroot
            set $Xnode = $XXnode
        end
    else
        set $Xnext = (hbt_node_t *)($Xnode->hbt_data[1] & ~0x3)
        if ($Xnode->hbt_data[1] & 0x1)
            set $Xnode = $Xnext
        else
            if $Xnext
                hbt_find_leftmost $Xnext
                set $Xnode = $XXnode
            else
                set $Xnode = 0
            end
        end
    end
end

define hbt_print_next
    set $Xroot = (hbt_node_t *) $arg0
    set $Xnode = (hbt_node_t *) $arg1
    hbt_iterate_next $Xroot $Xnode
    printf "%p\n", $Xnode
end

define hbt_print_tree
    set $Xroot = (hbt_node_t *) $arg0
    set $Xnode = (hbt_node_t *) 0
    hbt_iterate_next $Xroot $Xnode
    while $Xnode
        printf "%p\n", $Xnode
        hbt_iterate_next $Xroot $Xnode
    end
end

define hbt_max_element
    set $Xroot = (hbt_node_t *) $arg0
    if $Xroot
        set $Xnode = $Xroot
        set $Xnext = (hbt_node_t *)($Xnode->hbt_data[1] & ~0x3)
        while $Xnext
            set $Xnode = $Xnext
            set $Xnext = (hbt_node_t *)($Xnode->hbt_data[1] & ~0x3)
        end
    else
        set $Xnode = (hbt_node_t *) 0
    end
end

#
# patricia
#
define patricia_find_leftmost
    set $X1bit = (u_int16_t) $arg0
    set $X1node = (patnode *) $arg1
    while ($X1bit < $X1node->bit)
        set $X1bit = $X1node->bit
    set $X1node = $X1node->left
    end
    set $Xpnode = $X1node
end

define patricia_key
    set $X2root = (patroot *) $arg0
    set $X2node = (patnode *) $arg1
    if ($X2root->key_is_ptr)
        set $Xpkey = $X2node->patnode_keys.key_ptr[0] + $X2root->key_offset
    else
        set $Xpkey = $X2node->patnode_keys.key + $X2root->key_offset
    end
end

define patricia_key_test
    set $X3key = (u_int8_t *) $arg0
    set $X3bit = (u_int16_t) $arg1
    if (($X3key[$X3bit >> 8]) & (~$X3bit & 0xff))
        set $Xpkeytest = 1
    else
        set $Xpkeytest = 0
    end
end

define patricia_find_next
    set $X4root = (patroot *) $arg0
    set $X4node = (patnode *) $arg1
    set $X4current = $X4root->root
    if ($X4current == 0)
        set $Xpnode = (patnode *) 0
    else
        if ($X4node == 0)
            patricia_find_leftmost 0 $X4current
        else
            set $X4lastleft = (patnode *) 0
        patricia_key $X4root $X4node
        set $X4bit = (u_int16_t) 0
        while ($X4bit < $X4current->bit)
            set $X4bit = $X4current->bit
            patricia_key_test $Xpkey $X4bit
            if (($X4bit < $X4node->length) && ($Xpkeytest == 1))
                set $X4current = $X4current->right
            else
                set $X4lastleft = $X4current
            set $X4current = $X4current->left
            end
        end
        if ($X4lastleft)
            patricia_find_leftmost $X4lastleft->bit $X4lastleft->right
        else
            set $Xpnode = (patnode *) 0
        end
        end
    end
end

#
# Cloned from patricia_length_to_bit()
#
define patricia_length_to_bit
    set $X5len = $arg0
    if ($X5len)
        set $Xpbitlen = ((($X5len - 1) << 8) | 0xff)
    else
        set $Xpbitlen = 0
    end
end

#
# patricia_compare
#
define patricia_compare
    set $X7key0 = (u_int8_t *) $arg0
    set $X7key1 = (u_int8_t *) $arg1
    set $X7keylen = $arg2
    set $X7index = 0
    set $Xpcompare = 0
    while ($X7index < $X7keylen)
        if ($X7key0[$X7index] != $X7key1[$X7index])
            set $Xpcompare = 1
            set $X7index = $X7keylen
        else
            set $X7index = $X7index + 1
        end
    end
end

#
# Cloned from patricia_get_inline()
#
define patricia_lookup
    set $X6root = (patroot *) $arg0
    set $X6key = (u_int8_t *) $arg1
    set $X6current = (patnode *) $X6root->root
    if ($X6current == 0)
        set $Xpnode = (patnode *) 0
    else
        set $X6bit = 0
        patricia_length_to_bit $X6root->key_bytes
        while ($X6bit < $X6current->bit)
            set $X6bit = $X6current->bit
            patricia_key_test $X6key $X6bit
            if (($X6bit < $Xpbitlen) && ($Xpkeytest == 1))
                set $X6current = $X6current->right
            else
                set $X6current = $X6current->left
            end
        end
        if ($X6current->length != $Xpbitlen)
            set $Xpnode = (patnode *) 0
        else
            patricia_key $X6root $X6current
            patricia_compare $Xpkey $X6key $X6root->key_bytes
            if ($Xpcompare)
                set $Xpnode = (patnode *) 0
            else
                set $Xpnode = $X6current
            end
        end
    end
end

#
# patricia_walk root cast
#
# Walk a patricia and print each node after casting it.
define patricia_walk
    patricia_find_next $arg0 0
    while ($Xpnode)
        print {$arg1} $Xpnode
        patricia_find_next $arg0 $Xpnode
    end
end
#
# itable
#
define itable16_lookup
    set $tab=(itable16_t *)$arg0
    set $idx16=(index16_t)$arg1
    set $centry=($idx16 >> 12)
    set $cbuck=($idx16 >> 6) & 63
    set $can=(void **)$tab->cans[$centry]
    set $it16_ptr=0
    if $can
        set $bp=(void **)$can[$cbuck]
        if $bp
            set $it16_ptr=$bp[$idx16 & 63]
        end
    end
end

#
# Usage:
#
# lookup_ift16 itable_ptr index
#
define lookup_ift16
    set $table=(itable16_t *)$arg0
    set $idx = (index16_t) $arg1
    itable16_lookup $arg0 $arg1
    if $it16_ptr && $it16_ptr != 0xdeadbef0
    printf "%p\n", $it16_ptr
        print *($arg2 *)$it16_ptr
    end
end

#
# Usage:
#
# dump_ift16_n itable_ptr max_index
#
define dump_ift16_n
    set $table=(itable16_t *)$arg0
    set $i = 0
    while ($i < $arg1)
        itable16_lookup $arg0 $i
    if $it16_ptr && $it16_ptr != 0xdeadbef0
        printf "%d %p\n", $i, $it16_ptr
    end
        set $i = $i+1
    end
end

define dump_ift_n
    set $table=(itable_t *)$arg0
    set $i = 0
    while ($i < $table->itab_maxentry)
    set $itb = $table->itab_indirect[($i>>6) & 63]
    if $itb
        set $it_ptr = $itb->itb_entry[$i & 63]
        if $it_ptr
        printf "%d %p\n", $i, $it_ptr
        end
    end
    set $i = $i+1
    end
end

define itable32_lookup
    set $table=(itable32_t *)$arg0
    set $idx = (index32_t) $arg1
    set $lower=$idx&0xffff
    set $upper=($idx >> 16) & 0xffff
    set $ptr=0
    if $table && $table->itable32_upper
    itable16_lookup $table->itable32_upper $upper
    if $it16_ptr
        set $ift16=$it16_ptr
        itable16_lookup $ift16 $lower
    end
    end
end

define dump_ift32_n
    set $table=(itable32_t *)$arg0
    set $i = 0
    while ($i < $arg1)
        itable32_lookup $arg0 $i
    if $it16_ptr && $it16_ptr != 0xdeadbef0
        printf "%d %p\n", $i, $it16_ptr
    end
        set $i = $i+1
    end
end



define im_dr_get_next
    set $Xim_dr = (indexmap_dr_t*)$arg0
    set $Xpindex = (indexmap_index_t)$arg1
    if $Xpindex <= $Xim_dr->im_start
        set $Xvalue = $Xim_dr->value
        set $Xpindex = $Xim_dr->im_start
    end
end

define index_map_get_next
    set $Xim = (indexmap_base_t)*$arg0
    set $Xpindex = (indexmap_index_t)$arg1
    if $Xim->type == 0
    	printf "Indexmap type Direct\n"
    	while $Xpindex < $Xim->base_max    
    	    im_dr_get_next $Xim $Xpindex
            printf "Index %d \t Value %d", $Xpindex $Xvalue
        end
    end
end


define print_mac
    set $XXmac = (u_int8_t *) $arg0
    set $XXcount = 0
        while $XXcount < 6
           if $XXcount
               printf ":%02x", $XXmac[$XXcount]
           else
               printf "%02x", $XXmac[$XXcount]
           end
           set $XXcount += 1
      end
end


#
# thread next
# arg0 thread
#
define thread_next_node
    set $XXthead = (thread *) $arg0
    set $Xtnext = $XXthead->down
end

#
# thread circular top
# verifies if thread is null and returns head
#
define thread_circular_top
    set $Xhthread = (thread * ) $arg0

    if ($Xhthread->down == $Xhthread)
        set $Xthead = 0
    else
        set $Xthead = $Xhthread->down
    end
end


#
# thread circular thread next
# iterates through the nodes of circular thread
#
define thread_circular_thread_next
    set $Xhchain = (thread *) $arg0
    set $Xthead = (thread *) $arg1

    if ($Xthead)
        thread_next_node $Xthead

        if ($Xhchain == $Xtnext)
            set $Xthead = 0
        else
            set $Xthead = $Xtnext
        end
    else
        thread_circular_top $Xhchain
    end
end


define print_ifl_by_index
    set $xifl = 0
    itable32_lookup $arg0 $arg1
    if $it16_ptr && $it16_ptr != 0xdeadbef0
        set $xifl = (l2ald_ifl_t *)$it16_ptr
        printf "%s(%d)", $xifl->l2d_ifl_name, $arg1
    end
end

define print_bd_by_index
    set $xifl = 0
    itable16_lookup $arg0 $arg1
    if $it16_ptr && $it16_ptr != 0xdeadbef0
        set $xbd = (l2ald_bd_t *)$it16_ptr
        set $rtt = (l2ald_rtt_t *)$xbd->l2d_bd_parent_rtt      
        if $rtt
            printf "%s/%s/", $rtt->l2d_rtt_lr_name, $rtt->l2d_rtt_name 
        end
    
        printf "%s(%d)", $xbd->l2d_bd_name, $arg1
    end
end


#dump l2ald ifd by index
define l2ald_ifd_by_index
    set $max = 1000
#    if $arg0
#        set $max = $arg0
#    end    
    set $table = (itable16_t *)l2ald.l2_ifdindex_tbl
    set $i = 0
    printf "    ifd             name    index   flags   type\n"
    while ($i < $max)
        itable16_lookup $table $i
        if $it16_ptr && $it16_ptr != 0xdeadbef0
            set $Xifd = (l2ald_ifd_t *)$it16_ptr
            printf "%p  %16s %4d %8d %8d\n",\
                    $Xifd, $Xifd->l2d_ifd_name, $Xifd->l2d_ifd_index,\
                    $Xifd->l2d_ifd_flags, $Xifd->l2d_ifd_media.ifm_porttype
        end
        set $i = $i+1
    end
end


#dump l2ald_ifd_list
define l2ald_ifd_list
    set $Xproot = &l2ald.l2_ifdname_tree
    patricia_find_next $Xproot 0
    printf "    ifd             name    index   flags   type\n"
    while ($Xpnode)
        set $Xifd = (l2ald_ifd_t *)((char *)$Xpnode - \
                         ((size_t)&((l2ald_ifd_t *)0)->l2d_ifd_node))
        printf "%p  %16s %4d %8x %8d\n",\
                $Xifd, $Xifd->l2d_ifd_name, $Xifd->l2d_ifd_index,\
                $Xifd->l2d_ifd_flags, $Xifd->l2d_ifd_media.ifm_porttype

        patricia_find_next $Xproot $Xpnode
    end
end

#
#dump l2ald_ifl_list
#
define l2ald_ifl_list
    set $Xproot = &l2ald.l2_iflname_tree
    patricia_find_next $Xproot 0
    printf "    ifl                 name    ifl_index  ifd_index    state   flags\n"
    while ($Xpnode)
        set $Xifl = (l2ald_ifl_t *)((char *)$Xpnode - \
                            ((size_t)&((l2ald_ifl_t *)0)->l2d_ifl_node))
        printf "%p  %20s %8d %8d %#8x %#10x\n",\
                    $Xifl, $Xifl->l2d_ifl_name, $Xifl->l2d_ifl_index.x,\
                    $Xifl->l2d_ifd_index, $Xifl->l2d_ifl_state,\
                    $Xifl->l2d_iflm_flags

        patricia_find_next $Xproot $Xpnode
    end
end     

#
#dump sh_rtt
#
define sh_rtt
    set $Xproot = &l2ald.l2_rttname_tree
    patricia_find_next $Xproot 0
    printf "    rtt                 name    rtt_index  flags    cflags\n"
    while ($Xpnode)
        set $Xrtt = (l2ald_rtt_t *)((char *)$Xpnode - \
                            ((size_t)&((l2ald_rtt_t *)0)->l2d_rtt_node))
        printf "%p  %20s %8d %#8x %#8x\n",\
		    $Xrtt, $Xrtt->l2d_rtt_name, $Xrtt->l2d_rtt_idx,\
 		    $Xrtt->l2d_rtt_flags, $Xrtt->l2d_rtt_cfg.l2d_rc_flags
   
        patricia_find_next $Xproot $Xpnode
    end
end

#
#dump sh_bd
#
#need to desplay for bridge_vtag_t
define sh_bd
    set $rtt = (l2ald_rtt_t *)$arg0
    set $Xproot = &$rtt->l2d_rtt_bd_tree
    patricia_find_next $Xproot 0
    printf "    BD    bd_index                 name    rts_state    flags   cflags\n"
    while ($Xpnode)
        set $Xbd = (l2ald_bd_t *)((char *)$Xpnode - \
                            ((size_t)&((l2ald_bd_t *)0)->l2d_bd_node))
        printf "%p  %4d %25s %#8x %#8x %#8x\n",\
                    $Xbd, $Xbd->l2d_bd_idx, $Xbd->l2d_bd_name, $Xbd->l2d_bd_rts_state,\
                    $Xbd->l2d_bd_flags, $Xbd->l2d_bd_cfg->l2d_bc_flags
    
        patricia_find_next $Xproot $Xpnode
    end
end

#
#dump sh_ifbd_bd
#
define sh_ifbd_bd
    set $bd = (l2ald_bd_t *)$arg0
    set $Xproot = &$bd->l2d_bd_ifbd_root
    patricia_find_next $Xproot 0
    printf "    IFBD   	 	BD	            IFL  	         state    flags   cflags\n"
    while ($Xpnode)
        set $Xifbd = (l2ald_ifbd_t *)((char *)$Xpnode - \
                            ((size_t)&((l2ald_ifbd_t *)0)->l2d_ifbd_bd_node))

        printf "%p ", $Xifbd
   	    if ($Xifbd->l2d_ifbd_bd)
   	        printf "(%p)%-15s ", \
		        $Xifbd->l2d_ifbd_bd, $Xifbd->l2d_ifbd_bd->l2d_bd_name
        else
	        printf "(%p)%-15s ", 0, ""
        end 

        if ($Xifbd->l2d_ifbd_ifl)
            printf "(%p)%-12s ", \
                $Xifbd->l2d_ifbd_ifl, $Xifbd->l2d_ifbd_ifl->l2d_ifl_name
        else
            printf "(%p)%-15s ", 0, ""
        end    

        printf "%#8x %#8x %#8x\n",\
                $Xifbd->l2d_ifbd_state, $Xifbd->l2d_ifbd_flags,\
                $Xifbd->l2d_ifbd_cfg.l2d_ifbdc_flags

        patricia_find_next $Xproot $Xpnode
    end 
end

#
# sh_ifl_vlan_name
#
define sh_ifl_vlan_name
    set $ifl = (l2ald_ifl_t *)$arg0
    set $Xhroot = (hbt_node_t *)$ifl->list_of_vlan_name
    set $Xnode = (hbt_node_t *) 0
    if ($Xhroot)
        set $Xoffset = (int) &(((vlan_name_config_t *)0)->vlan_name_node)
        hbt_iterate_next $Xhroot $Xnode
        while $Xnode
            set $vname = (vlan_name_config_t *) ((char *) $Xnode + $Xoffset)
            printf "%s\n", $vname->vlan_name
            hbt_iterate_next $Xhroot $Xnode
        end
    end    
end    

#
#dump sh_ifbd_ifl
#
define sh_ifbd_ifl
    set $ifl = (l2ald_ifl_t *)$arg0
    set $Xlist = (l2ald_ifbd_t *)$ifl->l2d_ifbd_list_head
    printf "    IFBD        BD \t\t\t  IFL \t\t\t  state    flags   cflags\n"
    while ($Xlist)
        set $Xifbd = (l2ald_ifbd_t *)$Xlist

        printf "%p ", $Xifbd
        if ($Xifbd->l2d_ifbd_bd)
            printf "(%p)%-15s ", \
                $Xifbd->l2d_ifbd_bd, $Xifbd->l2d_ifbd_bd->l2d_bd_name
        else
            printf "(%p)%-15s ", 0, ""
        end

        if ($Xifbd->l2d_ifbd_ifl)
            printf "(%p)%-12s ", \
                $Xifbd->l2d_ifbd_ifl, $Xifbd->l2d_ifbd_ifl->l2d_ifl_name
        else
            printf "(%p)%-15s ", 0, ""
        end

        printf "%#8x %#8x %#8x\n",\
                $Xifbd->l2d_ifbd_state, $Xifbd->l2d_ifbd_flags,\
                $Xifbd->l2d_ifbd_cfg.l2d_ifbdc_flags

        set $Xlist = $Xifbd->l2d_ifbd_iff_link->tqe_next
    end
end

define sh_mclag_tx_mac
    set $ent = (mclag_vmac_t *)$arg0
    while ($ent)
        printf "%p ", $ent
        print_mac $ent->mclag_mac_address.addr
        printf "\n"
        set $ent = $ent->mclag_vmac_link.tqe_next
    end
end    

define sh_mclag_irb_tx_mac
    set $ent = (mclag_irb_mac_t *)$arg0
    while ($ent)
        printf "%p ", $ent
        print_mac $ent->mclag_irb_mac_address.addr
        printf "\n"
        set $ent = $ent->mclag_irb_mac_link.tqe_next
    end
end    

define print_fwd_entry
    set $Xfwd = (l2ald_fwd_entry_t *)$arg0
    printf "%p  ", $Xfwd
    print_mac &$Xfwd->key.mac_address
    printf "  "
    print_bd_by_index l2ald.l2_vpls_bdindex_tbl $Xfwd->key.bd_id
    printf "  "
    print_ifl_by_index l2ald.l2_iflindex_tbl $Xfwd->ifl_index.x
    printf "\t%p\n", $Xfwd->pmclag_info
end

define l2ald_mh_vmac_list
    set $Xproot = $arg0
    patricia_find_next $Xproot 0
    printf "    Addr             mcae-id     rmac    flag\n"
    while ($Xpnode)
        set $Xmh_vmac = (l2ald_mclag_mh_vmac_t *)((char *)$Xpnode - \
                         ((size_t)&((l2ald_mclag_mh_vmac_t *)0)->mclag_mh_vmac_node))
        printf "%p %8d     ", \
                $Xmh_vmac, $Xmh_vmac->mclag_mh_vmac_key.mclag_ae_id
        print_mac &$Xmh_vmac->mclag_mh_vmac_key.mclag_mac_address
        printf "\t %d\n", $Xmh_vmac->mclag_flags
        patricia_find_next $Xproot $Xpnode
    end
end

define l2ald_rgid_list
    set $Xproot = &l2ald.l2_mclag_info.l2_mclag_rg_tree
    patricia_find_next $Xproot 0
    printf "    RG             id     rmac_list   remote_sh_vmacs    remote_mh_vmacs\n"
    while ($Xpnode)
        set $Xrg = (l2ald_mclag_rg_t *)((char *)$Xpnode - \
                         ((size_t)&((l2ald_mclag_rg_t *)0)->rg_node))
        printf "%p %8d \t%p \t%p \t%p\n", \
                $Xrg, $Xrg->rg_id, &$Xrg->rg_rmac_list, &$Xrg->rg_remote_sh_vmacs_tree, &$Xrg->rg_remote_mh_vmacs_tree
 
        patricia_find_next $Xproot $Xpnode
    end
end



# Hash table code
# How to walk a hash table
#
define fwd_entry_walk
    set $Xhtable = (hash_table_t *)l2ald.fwd_entry_htb
    set $Xhindx = 0
    set $Xthead = 0
    set $Xoffset = (int)(&((l2ald_fwd_entry_t *)0)->h_entry)
    set $Xcount = 0
    
    printf "Address   MAC address          bd_index          IFL Name    pmclag_info\n"
    while $Xhindx < $Xhtable->table_size
        set $Xhbkt = &($Xhtable->bucket[$Xhindx])
	set $Xhead = &($Xhbkt->hash_chain)
        thread_circular_top $Xhead
	while $Xthead != 0
	    set $Xfwd = (l2ald_fwd_entry_t *) ((char *) $Xthead - $Xoffset)
	    print_fwd_entry $Xfwd
            set $Xcount = $Xcount + 1
            thread_circular_thread_next $Xhead $Xthead
	end
        set $Xhindx = $Xhindx + 1
    end
    printf "Total cound = %d\n", $Xcount
end


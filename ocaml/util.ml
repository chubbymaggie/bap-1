
(** Generally useful things.

    This module contains functions that are used in BAP, but which are
    not at all BAP specific.

    @author Ivan Jager
*)

(** The identity function *)
let id = fun x -> x

(** Curry a tupled function *)
let curry f = fun x y -> f(x,y)

(** The opposite of [curry] *)
let uncurry f = fun (x,y) -> f x y

(** [foldn f i n] is f (... (f (f i n) (n-1)) ...) 0 *)
let rec foldn ?(t=0) f i n =  match n-t with
  | 0 -> f i 0
  | _ when n>t -> foldn f (f i n) (n-1)
  | -1 -> i
  | _ -> raise (Invalid_argument "negative index number in foldn")


(** [mapn f n] is the same as [f 0; f 1; ...; f n] *)
let mapn f n =
  List.rev (foldn (fun l i -> f(n-i)::l) [] n)
  (* List.rev is needed to make side effects happen in the same order *)


(** @return a union b, assuming a and b are sets *)
let list_union a b = 
  List.fold_left (fun acc x ->
		    if List.mem x b then acc else x::acc) b a
;;
  
(** @return a intersect b, assuming a and b are sets *)
let list_intersection a b =
  List.rev(List.fold_left (fun acc x ->
		    if List.mem x b then x::acc else acc) [] a)
;;

(** @return true if the intersection of two lists is not empty *)
let list_does_intersect a b =
  List.exists (fun x -> List.mem x a) b


(** Calls f with whichever of it's arguments is smaller first, and the longer
    one second. *)
let shortest_first f a b =
  let (la, lb) = (List.length a, List.length b) in
  if lb < la then f lb la else f la lb
    

(** @return a - b, assuming a and b are sets *)
let list_difference a b = 
    List.rev  (List.fold_left (fun acc x ->
			      if List.mem x b then
				acc
			      else
				x :: acc) [] a)
      
(** {list_subset a b} returns true when all elements in a are also in b *)
let list_subset a b =
  List.for_all (fun x -> List.mem x b) a

(** @return true when both sets contain the same elements *)
let list_set_eq a b = list_subset a b && list_subset b a


(** [union_find map items], where [map] is a mapping from items to
    their dependencies, finds independent elements in [items] *)
let union_find map items =
  let add_one res item =
    let set = map item in
    let (joined,indep) =
      List.partition (fun (s,is) -> list_does_intersect s set) res
    in
    let joined =
      List.fold_left
	(fun (s,is) (s2,is2) -> (list_union s2 s, List.rev_append is2 is))
	(set,[item]) joined
    in
    joined::indep
  in
  let res = List.fold_left add_one [] items in
  List.map snd res




(** Like [List.fold_left] but the arguments go in the same order as most fold functions.
    
    This exists, because I got fed up with fold_left being backwards.
*)
let list_foldl f l a = List.fold_left (fun i a -> f a i) a l

(** Pop the first element off a list ref. *)
let list_pop l =
  match !l with
  | x::xs -> l := xs; x
  | [] -> failwith "hd"

(** Push an element onto the front of a list ref. *)
let list_push l v =
  l := v :: !l

(** @return the last element of a list *)
let rec list_last = function
  | [x] -> x
  | _::x -> list_last x
  | [] -> raise (Invalid_argument("list_last expects non-empty list"))

(** @return (lst,last) where [lst] is the input lst minus 
    the last element [last]. @raise Invalid_argument if [lst] is empty *)
let list_partition_last lst = 
  match List.rev lst with
  | [x] -> ([],x)
  | x::ys -> (List.rev ys,x)
  | _ -> raise (Invalid_argument "list_partition_last expects non-empty list")

(** Like [list_last] but returns an option rather than failing *)
let list_last_option = function [] -> None | x -> Some(list_last x)

let list_filter_some f =
  let rec helper r l =
    match l with
    | x::xs -> helper (match f x with Some s -> s::r | None -> r) xs
    | [] -> List.rev r
  in
  helper []

let rec list_find_some f = function
  | x::xs -> (match f x with Some s -> s | None -> list_find_some f xs)
  | [] -> raise Not_found


(** [list_count f l] counts the number of items in [l] for which the
    predicate [f] is true. *)
let list_count f =
  List.fold_left (fun c x -> if f x then c+1 else c) 0

(** [list_unique l] returns a list of elements that occur in [l], without
    duplicates. (uses [=] and [Hashtbl.hash])  *)
let list_unique l =
  let h = Hashtbl.create (List.length l) in
  List.iter (fun x -> Hashtbl.replace h x ()) l;
  Hashtbl.fold (fun k () ul -> k::ul) h [] 

let rec split_common_prefix la lb = 
  match la,lb with
  | [], _ -> ([], la, lb)
  | _, [] -> ([], la, lb)
  | h1::t1, h2::t2 ->
      if h1 = h2 then
	let (a,b,c) = split_common_prefix t1 t2 in
	(h1::a, b, c)
      else ([], la, lb)

let split_common_suffix la lb =
  let (s,rla,rlb) = split_common_prefix (List.rev la) (List.rev lb) in
  (List.rev s, List.rev rla, List.rev rlb)

(** a composition operator. [(f <@ g) x] = [f(g x)] *)
let (<@) f g = (fun x -> f(g x))

(** Given Some(a), returns a. Given None, raises Not_found *)
let option_unwrap o =
  match o with
  | Some(x) -> x
  | None -> raise Not_found

(** Maps an ['a option] to a ['b option], given a function [f : 'a -> 'b] *)
let option_map f = function
  | None -> None
  | Some x -> Some(f x)

(** Map Some items and drop others from the list.
*)
let list_map_some f =
  let rec help res = function
    | [] -> List.rev res
    | x::xs -> help (match f x with Some i -> (i::res) | None -> res) xs
  in
    help []
  

let list_join f =
  function
    | x::(_::_ as xs) -> List.fold_left f x xs
    | [x] -> x
    | [] -> raise(Invalid_argument "list_join on empty list")

(** Get the keys from a hash table 
  If a key has multiple bindings, it is included once per binding *)
let get_hash_keys ?(sort_keys=false) htbl =
  let l = Hashtbl.fold (fun key data prev -> key::prev) htbl [] in
  if (sort_keys) then List.sort (Pervasives.compare) l
  else l

(** Change the extension of a filename *)
let change_ext filename new_ext =
  let last_dot_pos = String.rindex filename '.' in
  let base = String.sub filename 0 last_dot_pos in
  String.concat "." [base; new_ext]

(* Get list of file name in directory (ordered by name) *)
let list_directory ?(sort_files=true) dir_path =
  let file_type = Unix.stat dir_path in
  if (file_type.Unix.st_kind <> Unix.S_DIR) 
    then raise (Invalid_argument "Not a directory.");
  let file_array =
    try Sys.readdir dir_path 
    with _ -> raise (Invalid_argument "Could not read dir.")
  in
  if (sort_files) then Array.sort (Pervasives.compare) file_array;
  Array.to_list file_array


module HashUtil (H:Hashtbl.S) =
struct

  let hashtbl_eq ?(eq=(=)) h1 h2 =
    let subtbl h1 h2 =
      H.fold
	(fun k v r ->
	   try r && eq v (H.find h2 k)
	   with Not_found -> false )
	h1 true
    in
      subtbl h1 h2 && subtbl h2 h1
end

(* GRR, Hashtbl doesn't ascribe to the Hashtbl.S signature *)
let hashtbl_eq ?(eq=(=)) h1 h2 =
  let subtbl h1 h2 =
    Hashtbl.fold
      (fun k v r ->
	 try r && eq v (Hashtbl.find h2 k)
	 with Not_found -> false )
      h1 true
  in
    subtbl h1 h2 && subtbl h2 h1


module StringSet = Set.Make(String) ;;

let trim_newline s = 
  if String.length s > 0 && String.get s ((String.length s) -1) = '\n'
  then	String.sub s 0 ((String.length s)-2)
  else	s


		    
  
let apply_option f k = 
  match f with
  | None -> k
  | Some(f') -> f' k

let rec print_separated_list ps sep lst = 
  let rec doit acc = function
    | [] -> acc^""
    | x::[] -> acc^(ps x)
    | x::y::zs -> let acc = (ps x)^sep in
	(doit acc (y::zs))
  in
    doit "" lst


(* stuff that should be in Int64 *)


(** Unsigned comparison of int64 *)
let int64_ucompare x y =
  if x < 0L && y >= 0L then 1
  else if x >= 0L && y < 0L then -1
  else Int64.compare x y

(** Unsigned int64 division *)
let int64_udiv x y =
  (* Reference: Hacker's Delight (Warren, 2002) Section 9.3 *)
  if y < 0L
  then if int64_ucompare x y < 0 then 0L else 1L
  else if x < 0L
  then let all_but_last_bit =
    Int64.shift_left (Int64.div (Int64.shift_right_logical x 1) y) 1
  in
    if int64_ucompare (Int64.sub x (Int64.mul all_but_last_bit y)) y >= 0 then
      Int64.succ all_but_last_bit
    else
      all_but_last_bit
  else Int64.div x y


(** Unsigned int64 remainder *)
let int64_urem x y =
  Int64.sub x (Int64.mul y (int64_udiv x y))

(** Unsigned maxima of int64 *)
let int64_umax x y =
  if int64_ucompare x y > 0 then x else y

(** Unsigned minimum of int64 *)
let int64_umin x y =
  if int64_ucompare x y < 0 then x else y

(* end stuff that should be in Int64 *)

(** execute f with fd_from remapped to fd_to.
    useful for redirecting output of external code;
    e.g., redirecting stdout when calling STP code. *)
let run_with_remapped_fd fd_from fd_to f =
  (* remap *)
  let fd_to_saved = Unix.dup fd_to in
  Unix.dup2 fd_from fd_to;

  (* execute *)
  let rv = f () in

  (* restore *)
  Unix.dup2 fd_to_saved fd_to;
  Unix.close fd_to_saved;

  rv

let rec take_aux acc = function
 | (_, 0) | ([],_) -> List.rev acc
 | (x::xs, n) -> take_aux (x::acc) (xs,n-1)

let take l n = take_aux [] (l, n)

(* list_firstindex l pred returns the index of the first list element
   that pred returns true on *)
let rec list_firstindex ?s:(s=0) l pred =
  if List.length l = 0 then 
    raise Not_found
  else if (pred (List.hd l)) then
    s
  else
    let tl = List.tl l in
    let next = s+1 in
    list_firstindex tl pred ~s:next

(* Insert elements in li to l before position n *)
let list_insert l li n =
  let rec list_split hl tl n =
    if n = 0 then 
      (List.rev hl,tl) 
    else
      let hl' = (List.hd tl) :: hl in
      let tl' = List.tl tl in
      let n' = n-1 in
      list_split hl' tl' n'
  in
  let hd,tl = list_split [] l n in
  hd @ li @ tl

(* Remove r elements in l starting at position s *)
let list_remove l s r =
  let aftere = s + r in
  let _,revl = List.fold_left
    (fun (i,l) e ->
       if i >= s && i < aftere then
	 (i+1,l)
       else
	 (i+1, e::l)
    ) (0,[]) l
  in
  List.rev revl

(** Compare two lists using f.  Compares pairs from both lists
    starting from the first elements using f, and returns the first
    non-zero result. If there is no non-zero result, zero is returned. *)
let list_compare f l1 l2 =
  let v = List.fold_left2
    (fun s e1 e2 ->
       match s with
       | Some(x) -> Some(x)
       | None -> 
	   let c = f e1 e2 in
	   (* If c is not zero, keep it *)
	   if c <> 0 then Some(c) else None
    ) None l1 l2 in
  match v with
  | None -> 0 (* Equal *)
  | Some(x) -> x (* Not equal *)

(** Given two lists, calls f with every possible combination *)
let list_cart_prod2 f l1 l2 =
  List.iter
    (fun x ->
       List.iter
	 (fun y ->
	    f x y
	 ) l2
    ) l1

(** Given three lists, calls f with every possible combination *)
let list_cart_prod3 f l1 l2 l3 =
  List.iter
    (fun x ->
       List.iter
	 (fun y ->
	    List.iter
	      (fun z ->
		 f x y z
	      ) l3
	 ) l2
    ) l1

(** Given four lists, calls f with every possible combination *)
let list_cart_prod4 f l1 l2 l3 l4 =
  List.iter
    (fun x ->
       List.iter
	 (fun y ->
	    List.iter
	      (fun z ->
		 List.iter
		   (fun w ->
		      f x y z w
		   ) l4
	      ) l3
	 ) l2
    ) l1


(** Calls f on each element of l, and returns the first Some(x)
    returned.  If no Some(x) are returned, None is returned. *)
let list_existssome f l =
  List.fold_left
    (fun state ele ->
       match state with
       | Some _ as x -> x (* Already found it *)
       | None -> f ele
    ) None l

(** Calls f on each element of l and if there is Some() value returned
    for each list member, returns Some(unwrapped list). If at least
    one returns None, None is returned instead. *)
let list_for_allsome f l =
  let b = List.fold_left
    (fun state ele ->
       match state with
       | false -> false
       | true -> (match f ele with
		  | Some _ -> true
		  | None -> false)
    ) true l
  in
  if b then Some(List.map (fun x -> option_unwrap (f x)) l) else None

(** Deletes the first occurrence of e (if it exists) in the list
    and returns the updated list *)
let list_delete l e = 
  let rec delete_aux acc = function
    | [] -> List.rev acc
    | x::xs when e == x -> (List.rev acc)@xs
    | x::xs -> delete_aux (x::acc) xs
  in
    delete_aux [] l

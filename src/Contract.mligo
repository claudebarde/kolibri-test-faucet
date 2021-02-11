type storage = 
[@layout:comb]
{
  paused: bool (* Contract is set on pause during transfer of tokens *);
  last_transfer: timestamp ; (* Contract allows transfer every 15 minutes *)
  transfer_to: address option;
  locked_amount: tez;
  admin: address;
  kolibri_address: address;
  harbinger_address: address;
}

type get_balance_param = address * (nat contract)
type kolibri_transfer_param = address * (address * nat)
type harbinger_param = string * (timestamp * nat)

type action =
| Transfer_request of address
| Get_balance of harbinger_param
| Transfer of nat
| Update_kolibri_address of address
| Update_harbinger_address of address
| Update_admin of address
| Withdraw of unit

(* Sends a first request to verify provided amount is correct *)
let transfer_request (p, s: address * storage): operation list * storage = 
  if Tezos.amount = 0tez
  then (failwith "NO_AMOUNT": operation list * storage)
  else
    if s.paused
    then (failwith "CONTRACT_PAUSED": operation list * storage)
    else
      (* Transfers can only happen every 15 minutes *)
      if s.last_transfer + 900 > Tezos.now
      then (failwith "15_MINUTES_DELAY" : operation list * storage)
      else
        (* Prepares call to Harbinger oracle *)
        let contract: (string * harbinger_param contract) contract = 
          match (Tezos.get_entrypoint_opt "%get" s.harbinger_address: (string * harbinger_param contract) contract option) with
          | None -> (failwith "HARBINGER_NOT_FOUND": (string * harbinger_param contract) contract)
          | Some c -> c in
        (* Prepares transaction to Harbinger *)
        let op = Tezos.transaction 
                  ("XTZ-USD", (Tezos.self("%get_balance"): harbinger_param contract)) 
                  0tez 
                  contract in

        [op],
        { s with 
          paused = true;
          transfer_to = Some p;
          locked_amount = Tezos.amount
        }

(* Sends a request to Kolibri contract to get admin's balance *)
let get_balance (p, s: harbinger_param * storage): operation list * storage = 
  if Tezos.sender <> s.harbinger_address
  then (failwith "UNAUTHORIZED_SENDER": operation list * storage)
  else
    if not s.paused
    then (failwith "CONTRACT_NOT_PAUSED": operation list * storage)
    else
      if p.0 <> "XTZ-USD"
      then (failwith "UNEXPECTED_CURRENCY": operation list * storage)
      else
        (* Verifies locked amount is correct *)
        let exchange_rate: nat = p.1.1 in
        if (2_000_000_000_000n / exchange_rate) * 1mutez <> s.locked_amount
        then (failwith "INCORRECT_AMOUNT": operation list * storage)
        else
          (* Prepares call to Kolibri contract *)
            let contract: get_balance_param contract =
              match (Tezos.get_entrypoint_opt "%getBalance" s.kolibri_address: get_balance_param contract option) with
              | None -> (failwith "KOLIBRI_NOT_FOUND": get_balance_param contract)
              | Some c -> c in
            (* Prepares transaction to Kolibri *)
            let op = Tezos.transaction 
                        (s.admin, (Tezos.self("%transfer"): nat contract)) 
                        0tez 
                        contract in

            ([op] : operation list), s

(* Receives admin's balance and sends transfer transaction to Kolibri *)
let transfer (blnc, s: nat * storage): operation list * storage = 
  if Tezos.sender <> s.kolibri_address
  then (failwith "UNAUTHORIZED_SENDER": operation list * storage)
  else
    if not s.paused
    then (failwith "CONTRACT_NOT_PAUSED": operation list * storage)
    else
      (* Checks if current balance is over 20 to transfer kUSD *)
      if blnc < 20n
      then (failwith "INSUFFICIENT_ADMIN_BALANCE": operation list * storage)
      else
        (* Prepares Kolibri contract reference *)
        let kolibri: kolibri_transfer_param contract =
          match (Tezos.get_entrypoint_opt "%transfer" s.kolibri_address: kolibri_transfer_param contract option) with
          | None -> (failwith "NO_CONTRACT_FOUND": kolibri_transfer_param contract)
          | Some c -> c in
        (* Prepares transfer operation to send to Kolibri contract *)
        let op = match s.transfer_to with
          | None -> (failwith "NO_RECIPIENT": operation)
          | Some r -> 
            let param: kolibri_transfer_param = s.admin, (r, 2_000_000_000_000_000_000n) in
            Tezos.transaction param 0tez kolibri
        in

        ([op] : operation list),
        { s with 
            paused = false; 
            last_transfer = Tezos.now; 
            transfer_to = (None: address option);
            locked_amount = 0tez }

let update_kolibri_address (p, s: address * storage): storage =
  if Tezos.sender <> s.admin
  then (failwith "NOT_AN_ADMIN": storage)
  else
    { s with kolibri_address = p }

let update_harbinger_address (p, s: address * storage): storage =
  if Tezos.sender <> s.admin
  then (failwith "NOT_AN_ADMIN": storage)
  else
    { s with harbinger_address = p }

let update_admin (p, s: address * storage): storage =
  if Tezos.sender <> s.admin
  then (failwith "NOT_AN_ADMIN": storage)
  else
    { s with admin = p }

let withdraw (s: storage): operation list * storage =
  if Tezos.sender <> s.admin
  then (failwith "NOT_AN_ADMIN": operation list * storage)
  else
  let recipient: unit contract = match (Tezos.get_contract_opt s.admin: unit contract option) with
    | None -> (failwith "NO_ADMIN_FOUND": unit contract)
    | Some c -> c in
  let op = Tezos.transaction unit Tezos.amount recipient in

  ([op] : operation list), s

let main (p,s: action * storage) =
 match p with
   | Transfer_request n -> transfer_request (n, s)
   | Get_balance n -> get_balance (n, s)
   | Transfer n -> transfer (n, s)
   | Update_kolibri_address n -> ([] : operation list), update_kolibri_address (n, s)
   | Update_harbinger_address n -> ([] : operation list), update_harbinger_address (n, s)
   | Update_admin n -> ([] : operation list), update_admin (n, s)
   | Withdraw n -> withdraw s

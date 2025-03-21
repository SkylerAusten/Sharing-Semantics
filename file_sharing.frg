#lang forge/temporal

// TN: note this works now: it will pre-load the script
option run_sterling "viz.js"

-- Trace Length
option max_tracelength 18
option min_tracelength 15

-- UNSAT Resolver (uncomment to use)
// option solver MiniSatProver
// option core_minimization rce
// option logtranslation 1
// option coregranularity 1

------------------------ Sigs ------------------------

sig Person {}

one sig Bobbi, Joe, Server extends Person {}

abstract sig PowerState {}

one sig On, Off extends PowerState {}

abstract sig Location {
    var location_owner: one Person,
    var location_items: set Item,
    var power_state: one PowerState
}

sig Drive extends Location {
    var shared_with_me: set Item
}

one sig BobbiDrive, JoeDrive extends Drive {}

sig Computer extends Location {}

one sig BobbiComputer, JoeComputer extends Computer {}

sig EmailServer extends Location {}

var abstract sig Item {
    var item_creator: one Person,
    var item_owner: one Person,
    var location: one Location,
    var shared_with: set Person
}

var sig File extends Item {
    var same_content: set File
}

var sig Folder extends Item {
    var folder_items: set File
}

var abstract sig EmailContent {}

var sig Attachment extends EmailContent {
    var attached: one Item
}

var sig Text extends EmailContent {}

var sig Link extends EmailContent {
    var points_to: one Item
}

var sig Email {
    var from: one Person,
    var to: set Person,
    var email_content: lone EmailContent
}

sig Inbox {
    var inbox_owner: one Person,
    var received: set Email,
    var sent: set Email,
    var drafts: set Email,
    var threads: set Email->Email
}

one sig BobbiInbox, JoeInbox extends Inbox {}

------------------------ Constraints ------------------------

pred modelProperties {
    -- An email in an inbox's drafts implies the email is "from" the inbox owner.
    all e: Email, i: Inbox | {e in i.drafts implies e.from = i.inbox_owner}

    -- An email in an inbox's sent implies the email is "from" the inbox owner.
    all e: Email, i: Inbox | {e in i.sent implies e.from = i.inbox_owner} 

    -- A file cannot have the same content as itself.
    no f: File | f in f.same_content

    -- All items specified as being at a given location will be in that location's location_items set.
    all l: Location, i: Item | i in l.location_items iff {i.location = l}

    -- A item must be in a drive to be shared with someone.
    all i: Item | some i.shared_with implies {i.location in Drive}

    -- An item cannot be shared with its owner.
    no i: Item | i.item_owner in i.shared_with

    -- No file can be both in someone's drive & that drive's shared_with_me.
    no i: Item, d: Drive | i in d.location_items and i in d.shared_with_me

    -- An item's location must have the same location_owner as the item's item_owner.
    all f: Item | f.location.location_owner = f.item_owner

    -- All items must have the same location as the folder they're in.
    all file: File, folder: Folder | file in folder.folder_items implies file.location = folder.location

    -- All same_content relations are reciprocal.
    all disj f1, f2: File | f2 in f1.same_content iff { f1 in f2.same_content }

    -- No item can be in more than one folder's items.
    no disj f1, f2: Folder, i: Item |
        (i in f1.folder_items) and (i in f2.folder_items)

    -- No item can be in more than one location's location_items.
    no disj l1, l2: Location, i: Item |
        (i in l1.location_items) and (i in l2.location_items)

    -- An foler cannot be in its own folder_items or any child folders's items.
    no f: Folder | f in f.^folder_items

    -- One person can only own one computer, one drive, and one inbox.
    -- And all computers, drives, and inboxes must be owned.
    #{Computer.location_owner} = #{Computer}
    #{Drive.location_owner} = #{Drive}
    #{Inbox.inbox_owner} = #{Inbox}

    -- No two emails can have the same content.
    no disj e1, e2: Email | {e1.email_content = e2.email_content and {e1.email_content + e2.email_content} != none }

    -- A item must be in a drive to be in another drive's shared_with_me.
    all i: Item | { i in Drive.shared_with_me implies {i.location in Drive}}

    -- An item shared with someone must be in that person's drive's shared_with_me.
    all i: Item, p: Person | {p in i.shared_with iff {i in ((location_owner.p) & Drive).shared_with_me}}

    -- An item NOT shared with someone must NOT be in that person's drive's shared_with_me.
    all i: Item, p: Person | {p not in i.shared_with implies {i not in ((location_owner.p) & Drive).shared_with_me}}

    -- An item in a folder must inherit the folder's shared_with.
    no file: File, folder: Folder | file in folder.folder_items and folder.shared_with not in file.shared_with 

    -- The email server must be owned by the Server person.
    EmailServer in Location implies {EmailServer.location_owner = Server}

    -- An attached item must be on the email server.
    all a: Attachment | a.attached.location = EmailServer

    -- A linked item must be in a Drive.
    all l: Link | l.points_to.location in Drive

    -- An email in sent or received must have some content & some "to."
    all e: Email, i: Inbox | (e in i.sent or e in i.received) implies some e.email_content and some e.to

    -- All email content must have some associated email.
    all ec: EmailContent | some e: Email | e.email_content = ec

    -- Server cannot own a Drive, Computer, or Inbox.
    no d: Drive | d.location_owner = Server
    no c: Computer | c.location_owner = Server
    no i: Inbox | i.inbox_owner = Server

    -- Every email must have some "from".
    all e: Email | some e.from

    -- An email in drafts cannot be in any inbox's sent or received.
    all disj i1, i2: Inbox, e: Email | e in i1.drafts implies {
        e not in (i2.sent + i2.received + i1.sent + i1.received + i2.drafts)
    }
}

pred ownership {
    BobbiDrive in Drive implies {BobbiDrive.location_owner = Bobbi}
    JoeDrive in Drive implies {JoeDrive.location_owner = Joe}

    BobbiComputer in Computer implies {BobbiComputer.location_owner = Bobbi}
    JoeComputer in Computer implies {JoeComputer.location_owner = Joe}

    BobbiInbox in Inbox implies {BobbiInbox.inbox_owner = Bobbi}
    JoeInbox in Inbox implies {JoeInbox.inbox_owner = Joe}
}

---------------------- Framing Helpers ----------------------

// TN: Removing a lot of duplication to make it easier to adapt if you _do_ want 
// these to vary over time later on. 

pred nochange_sig_Person {
    // This is tautologous at the moment 
    // Person = Person'
    
    // TN: I don't believe you need this `in`, if you have the equality already?
    //  (Although in the current formulation this is tautologous.)
    // Same comment goes for the other pairings.
    
    // This is tautologous at the moment 
    //Person in Person'
}

pred nochange_sig_Location {
    // This is tautologous at the moment
    // Location = Location'
    // Location in Location'
}

pred nochange_sig_Inbox {
    // This is tautologous at the moment
    // Inbox = Inbox'
    // Inbox in Inbox'
}

------------------------ Transitions ------------------------

pred doNothing {
    -- Guard(s):
    -- This should only run when the model is in its final state.
    finalState

    -- Action(s):
    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change.
    nochange_sig_Location 

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.location_items = l.location_items'
        l.location_items in l.location_items'

        l.power_state = l.power_state'
        l.power_state in l.power_state'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    -- No items or their properties change.
    Item = Item'
    Item in Item'

    File = File'
    File in File'

    Folder = Folder'
    Folder in Folder'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No file properties change.
        i.same_content = i.same_content'
        i.same_content in i.same_content'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No emails or their properties change.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

pred createFile[actor: Person, loc: Location] {
    -- Guard(s):
    -- The actor must own the location.
    loc.location_owner = actor

    -- The actor cannot be server.
    actor != Server

    -- The location must be powered on.
    loc.power_state = On

    -- Action(s):
    -- Create a new file.
    some f: File' - File {
        -- No other items change.
        Item' = Item + f
        Item in Item'

        File' = File + f
        File in File'

        Folder = Folder'
        Folder in Folder'

        -- Set the new file's location to the given location.
        f.location' = loc

        -- Set the new file's creator and owner.
        f.item_owner' = actor
        f.item_creator' = actor

        -- Ensure the new file isn't shared with anyone.
        no f.shared_with'

        -- Ensure the new content doesn't have any same_content.
        no f.same_content'

        -- Ensure loc only gains the one new file.
        loc.location_items' = loc.location_items + f
        loc.location_items in loc.location_items'
    }

    -- No existing item properties change.
    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No file properties change.
        i.same_content = i.same_content'
        i.same_content in i.same_content'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No existing locations or their properties change,
    -- except for loc.location_items.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.power_state = l.power_state'
        l.power_state in l.power_state'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    all l: (Location - loc) | {
        l.location_items = l.location_items'
        l.location_items in l.location_items'
    }

    -- No persons change.
    nochange_sig_Person

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No emails or their properties change.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

pred createFolder[actor: Person, loc: Location] {
    -- Guard(s):
    -- The actor must own the location.
    loc.location_owner = actor

    -- The actor cannot be server.
    actor != Server

    -- The location must be powered on.
    loc.power_state = On

    -- Action(s):
    -- Create a new folder.
    some f: Folder' - Folder | {
        -- No other items change.
        Item' = Item + f
        Item in Item'

        File = File'
        File in File'

        Folder' = Folder + f
        Folder in Folder'

        -- Set the new folder's location to the given location.
        f.location' = loc

        -- Set the new folder's creator and owner.
        f.item_owner' = actor
        f.item_creator' = actor

        -- Ensure the new folder isn't shared with anyone.
        no f.shared_with'

        -- Ensure the new folder has no items in it.
        no f.folder_items'

        -- Ensure loc only gains the one new folder.
        loc.location_items' = loc.location_items + f
        loc.location_items in loc.location_items'
    }

    -- No existing item properties change.
    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No file properties change.
        i.same_content = i.same_content'
        i.same_content in i.same_content'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No existing locations or their properties change,
    -- except for loc.location_items.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.power_state = l.power_state'
        l.power_state in l.power_state'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    all l: (Location - loc) | {
        l.location_items = l.location_items'
        l.location_items in l.location_items'
    }

    -- No persons change.
    nochange_sig_Person

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No emails or their properties change.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

pred moveItem[actor: Person, moved: File, destination: Folder] {
    -- Guard(s):
    -- There can only be one moved file.
    one moved
    one destination

    -- The actor cannot be server.
    actor != Server

    -- The location must be powered on.
    moved.location.power_state = On

    -- The items must not be on the EmailServer.
    moved.location != EmailServer

    -- The actor must own the item to be moved and the destination folder.
    moved.item_owner = actor
    destination.item_owner = actor

    -- The moved item cannot already be in the destination folder.
    moved not in destination.folder_items

    -- The moved item and destination folder must have the same location.
    moved.location = destination.location

    -- Action(s):
    -- Move the item into the destination folder's items.
    destination.folder_items' = destination.folder_items + moved
    destination.folder_items in destination.folder_items'

    -- If the item is currently in any folder, remove it from that folder's items.
    all f: (Folder - destination) | (f.folder_items' = f.folder_items - moved and f.folder_items' in f.folder_items)

    -- Reinforce that only one file moves.
    one folder_items' - folder_items

    -- Reinforce that the moved file only goes to one folder.
    one f: Folder | moved in f.folder_items'
    no f: Folder - destination | moved in f.folder_items'

    -- Update shared_with for the moved item to include those of the destination if not already included.
    moved.shared_with' = moved.shared_with + (destination.shared_with - moved.item_owner)

    all i: Item - moved | {
        i.shared_with' = i.shared_with
    }

    -- Update the shared_with_me for all drives of persons who are now sharing the moved item,
    -- otherwise they remain the same.
    all d: Drive | destination in d.shared_with_me => d.shared_with_me' = d.shared_with_me + moved else {
        d.shared_with_me' = d.shared_with_me
    }

    shared_with_me in shared_with_me'

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change,
    -- except drive shared_with_me.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.location_items = l.location_items'
        l.location_items in l.location_items'

        l.power_state = l.power_state'
        l.power_state in l.power_state'
    }

    -- No items or their properties change, except moved's shared_with (above).
    Item = Item'
    Item in Item'

    File = File'
    File in File'

    Folder = Folder'
    Folder in Folder'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with in i.shared_with'

        -- No file properties change.
        i.same_content = i.same_content'
        i.same_content in i.same_content'
    }

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No emails or their properties change.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

pred createEmail[actor: Person] {
    -- Guard(s):
    -- The actor cannot be server.
    actor != Server

    -- Action(s):
    -- Create a new email.
    some e: Email' - Email | {
        -- No other emails change.
        Email' = Email + e
        Email in Email'

        -- Set the new email's location to the actor's inbox.
        e in inbox_owner'.actor.drafts'

        -- Ensure the email's location's drafts only gains the one new email.
        inbox_owner'.actor.drafts' = inbox_owner'.actor.drafts + e
        inbox_owner'.actor.drafts in inbox_owner'.actor.drafts'

        -- Set the new email's from field to actor.
        e.from' = actor

        -- Ensure the new email has no "to" field or content.
        no e.to'
        no e.email_content'
    }

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.location_items = l.location_items'
        l.location_items in l.location_items'

        l.power_state = l.power_state'
        l.power_state in l.power_state'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    -- No items or their properties change.
    Item = Item'
    Item in Item'

    File = File'
    File in File'

    Folder = Folder'
    Folder in Folder'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No file properties change.
        i.same_content = i.same_content'
        i.same_content in i.same_content'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'

    }

    -- No existing emails or their properties change.
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- No inboxes or their properties change, except the actor's drafts.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.threads = i.threads'
        i.threads in i.threads'
    }

    all i: (Inbox - inbox_owner'.actor) | {
        i.drafts = i.drafts'
        i.drafts in i.drafts'
    }
}

pred setRecipients[actor: Person, email: Email, recipients: Person] {
    -- Guard(s):
    -- The actor cannot be server.
    actor != Server

    -- Server cannot be in recipients.
    Server not in recipients

    -- The email must still be in the actor's drafts.
    email in inbox_owner.actor.drafts

    -- The email's to cannot already be recipients.
    email.to != recipients

    -- An email can't be sent to one's self.
    -- TODO: Remove and account for in send/attach.
    actor not in recipients

    -- Action(s):
    -- Set the specified email's recipients.
    email.to' = recipients

    -- No existing emails or their properties change, except the specified email's to.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    all e: (Email - email) | {
        e.to = e.to'
        e.to in e.to'
    }

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.location_items = l.location_items'
        l.location_items in l.location_items'

        l.power_state = l.power_state'
        l.power_state in l.power_state'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    -- No items or their properties change.
    Item = Item'
    Item in Item'

    File = File'
    File in File'

    Folder = Folder'
    Folder in Folder'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No file properties change.
        i.same_content = i.same_content'
        i.same_content in i.same_content'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'

    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

pred removeRecipients[actor: Person, email: Email] {
    -- Guard(s):
    -- The actor cannot be server.
    actor != Server

    -- Some email recipients must already exist.
    some email.to

    -- The email must still be in the actor's drafts.
    email in inbox_owner.actor.drafts

    -- Action(s):
    -- Set the specified email's recipients to none.
    email.to' = none

    -- No emails or their properties change, except the specified email's to.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    all e: (Email - email) | {
        e.to = e.to'
        e.to in e.to'
    }

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.location_items = l.location_items'
        l.location_items in l.location_items'

        l.power_state = l.power_state'
        l.power_state in l.power_state'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    -- No items or their properties change.
    Item = Item'
    Item in Item'

    File = File'
    File in File'

    Folder = Folder'
    Folder in Folder'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No file properties change.
        i.same_content = i.same_content'
        i.same_content in i.same_content'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

pred attachFile[actor: Person, item: File, email: Email] {
    -- Guard(s):
    -- The actor cannot be server.
    actor != Server

    -- The file's location must be powered on.
    item.location.power_state = On

    -- The item to attach must be owned by the actor.
    item.item_owner = actor

    -- The item to attach must be on the actor's computer.
    item.location = location_owner.actor & Computer

    -- The email must be in the actor's drafts.
    email in inbox_owner.actor.drafts

    -- The email must have no existing content.
    no email.email_content

    -- Action(s):
    -- Create a new file and attachment.
    some a: Attachment' - Attachment | {
        some file: File' - File | {
            -- Only this new file is created.
            Item' = Item + file

            File' = File + file
            File in File'

            Folder = Folder'
            Folder in Folder'

            -- Set the new file's properties.
            file.location' = EmailServer
            file.item_owner' = Server
            file.item_creator' = actor
            no file.shared_with'

            file.same_content' = (item + item.same_content)
            item.same_content' = item.same_content + file

            -- Set the same content for all relevant files.
            all i: item.same_content | {
                i.same_content in i.same_content'
                i.same_content' = i.same_content + file
            } 

            a.attached' = file
            EmailServer.location_items' = EmailServer.location_items + file
        }

        -- No other email contents change.
        EmailContent' = EmailContent + a
        EmailContent in EmailContent'

        Attachment' = Attachment + a
        Attachment in Attachment'

        Text = Text'
        Text in Text'

        Link = Link'
        Link in Link'

        -- The attachment must be included in the email.
        email.email_content' = a
    }

    -- No non-related items' same_content changes.
    all i: (Item - item) - item.same_content | {
        i.same_content = i.same_content'
        i.same_content in i.same_content'    
    }

    -- No existing email contents or their properties change.  
    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'

    }

    -- No emails or their properties change, except for the newly attached e-mail.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'
    }

    all e: (Email - email) | {
        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- All location_items other than the email server's remain the same.
    all l: Location - EmailServer | {
        l.location_items = l.location_items'
    }

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.power_state = l.power_state'
        l.power_state in l.power_state'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'

        -- No existing items are removed.
        l.location_items in l.location_items'
    }

    -- No existing items or their properties change.
    Item in Item'  

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        i.same_content in i.same_content'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }


    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

pred attachFolder[actor: Person, item: Folder, email: Email] {
    -- Guard(s):
    -- The actor cannot be server.
    actor != Server

    -- The folder's location must be powered on.
    item.location.power_state = On

    -- The item to attach must be owned by the actor.
    item.item_owner = actor

    -- The item to attach must be on the actor's computer.
    item.location = location_owner.actor & Computer

    -- The email must be in the actor's drafts.
    email in inbox_owner.actor.drafts

    -- The email must have no existing content.
    no email.email_content

    -- Action(s):
    -- Create a new file and attachment.
    some a: Attachment' - Attachment | {
        some folder: Folder' - Folder | {
            -- Only this new folder is created.
            Folder' = Folder + folder
            folder.location' = EmailServer
            folder.item_owner' = Server
            folder.item_creator' = actor
            no folder.shared_with'

            a.attached' = folder

            let cloned_files = { cloned: File' | cloned not in File and cloned in File' - File } | {
                #{cloned_files} = #{item.folder_items}
                cloned_files = folder.folder_items'

                -- Only these new files are created.
                File' = File + cloned_files

                cloned_files.location' = EmailServer
                cloned_files.item_owner' = Server
                cloned_files.item_creator' = actor
                no cloned_files.shared_with'

                EmailServer.location_items' = EmailServer.location_items + folder + cloned_files

                all orig: item.folder_items | one clone: cloned_files | {
                    clone.same_content' = (orig + orig.same_content)  -- Mapping same_content individually.
                    orig.same_content' = orig.same_content + clone
                    
                    all i: orig.same_content | {
                        i.same_content' = i.same_content + clone
                    }
                }
            }
        }

        -- No other email contents change.
        EmailContent' = EmailContent + a
        EmailContent in EmailContent'

        Attachment' = Attachment + a
        Attachment in Attachment'

        Text = Text'
        Text in Text'

        Link = Link'
        Link in Link'

        -- The attachment must be included in the email.
        email.email_content' = a
    }

    -- No email contents or their properties change,
    -- except for the newly created one.

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'

    }

    -- No emails or their properties change,
    -- except for the newly attached e-mail.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'
    }

    all e: (Email - email) | {
        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    all l: Location - EmailServer | {
        l.location_items = l.location_items'
    }

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.power_state = l.power_state'
        l.power_state in l.power_state'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'

        -- No existing items are removed.
        l.location_items in l.location_items'
    }

    -- No items or their properties change.
    Item in Item'

    all i: (Item - item.folder_items) - item.folder_items.same_content | {
        i.same_content in i.same_content'
        i.same_content = i.same_content'
    }

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        i.same_content in i.same_content'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }


    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

pred addText[actor: Person, email: Email] {
    -- Guard(s):
    -- The actor cannot be server.
    actor != Server

    -- TODO: Power?

    -- The email must be in the actor's drafts.
    email in inbox_owner.actor.drafts

    -- The email must have no existing content.
    no email.email_content

    -- Action(s):
    -- Create a new email text.
    one t: Text' - Text | {
        -- No other email contents change.
        EmailContent' = EmailContent + t
        Text' = Text + t

        -- The text must be included in the email.
        email.email_content' = t
    }

    -- No email contents or their properties change,
    -- except for the newly created one.
    EmailContent in EmailContent'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No emails or their properties change,
    -- except for the newly attached e-mail.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'
    }

    all e: (Email - email) | {
        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.location_items = l.location_items'
        l.location_items in l.location_items'

        l.power_state = l.power_state'
        l.power_state in l.power_state'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    -- No items or their properties change.
    Item = Item'
    Item in Item'

    File = File'
    File in File'

    Folder = Folder'
    Folder in Folder'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No file properties change.
        i.same_content = i.same_content'
        i.same_content in i.same_content'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

pred addLink[actor: Person, item: Item, email: Email] {
    -- Guard(s):
    -- The actor cannot be server.
    actor != Server

    -- TODO: Power?

    -- The email must be in the actor's drafts.
    email in inbox_owner.actor.drafts

    -- The email must have no existing content.
    no email.email_content

    -- The item must be owned by or shared with the actor.
    (item.location = location_owner.actor & Drive) or 
    (actor in item.shared_with)

    -- Action(s):
    -- Create a new email text.
    some l: Link' - Link | {
        -- No other email contents change.
        EmailContent' = EmailContent + l
        EmailContent in EmailContent'

        Link' = Link + l
        Link in Link'

        -- The text must be included in the email.
        email.email_content' = l

        l.points_to' = item
    }

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    -- No email contents or their properties change,
    -- except for the newly created one.
    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No emails or their properties change,
    -- except for the newly attached e-mail.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'
    }

    all e: (Email - email) | {
        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties cha nge.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.location_items = l.location_items'
        l.location_items in l.location_items'

        l.power_state = l.power_state'
        l.power_state in l.power_state'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    -- No items or their properties change.
    Item = Item'
    Item in Item'

    File = File'
    File in File'

    Folder = Folder'
    Folder in Folder'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No file properties change.
        i.same_content = i.same_content'
        i.same_content in i.same_content'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

pred removeEmailContent[actor: Person, email: Email] {
    -- Guard(s):
    -- The actor cannot be server.
    actor != Server

    -- TODO: Power?

    -- The email must be in the actor's drafts.
    email in inbox_owner.actor.drafts

    -- The email must have some existing content.
    some email.email_content

    -- Action(s):
    -- If email content is text...

    -- If email content is a link...

    -- If email content is an attachment...
    -- TODO: attachment
    -- Delete the item(s) in the EmailServer.

    -- Delete the email server item mapping.

    -- Specify there's no email content.
    no email.email_content'

    -- Only email's email content is removed.
    EmailContent' = EmailContent - email.email_content
    EmailContent' in EmailContent

    Attachment' = Attachment - email.email_content
    Attachment' in Attachment

    Link' = Link - email.email_content
    Link' in Link

    Text' = Text - email.email_content
    Text' in Text

    all ec: EmailContent' | {
        -- No other attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No other link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    all e: (Email - email) | {
        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.location_items = l.location_items'
        l.location_items in l.location_items'

        l.power_state = l.power_state'
        l.power_state in l.power_state'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    -- No items or their properties change.
    Item = Item'
    Item in Item'

    File = File'
    File in File'

    Folder = Folder'
    Folder in Folder'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No file properties change.
        i.same_content = i.same_content'
        i.same_content in i.same_content'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No emails or their to/from change.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'
    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

fun linkFiles[email: Email]: Item { email.email_content.points_to + email.email_content.points_to.folder_items }

pred sendEmail[actor: Person, email: Email] {
    -- Guard(s):
    -- The actor cannot be server.
    actor != Server

    -- TODO: Power?

    -- The email must still be in the actor's drafts.
    email in inbox_owner.actor.drafts

    -- The email's must have some sender, recipients, and content.
    some email.to
    some email.from
    some email.email_content

    -- Action(s):
    -- Email moves to sender's sent & recipients' received.
    inbox_owner.actor.sent in inbox_owner.actor.sent'
    inbox_owner.actor.sent' = inbox_owner.actor.sent + email

    all r: email.to | inbox_owner.r.received in inbox_owner.r.received'
    all r: email.to | inbox_owner.r.received' = inbox_owner.r.received + email

    -- Email is no longer in the actor's drafts.
   (inbox_owner.actor).drafts' in (inbox_owner.actor).drafts
   (inbox_owner.actor).drafts' = (inbox_owner.actor).drafts - email

    -- No inboxes change.
    nochange_sig_Inbox

    -- No inbox ownerships or threads change (threads are updated via sendReply).
    all i: Inbox | {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.threads = i.threads'
        i.threads in i.threads'
    }

    // -- No inbox sent or drafts are changed except for the actor's.
    all i: Inbox - (inbox_owner.actor) | {
        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'
    }

    // -- No inbox receiveds change except for the email recipients.
    all r: email.to | all i: Inbox - inbox_owner.r | {
        i.received = i.received'
        i.received in i.received'
    }

    -- If email content is a link, share the item(s) it points to with recipients.
    all i: (linkFiles[email]) | {
        i.shared_with' = i.shared_with + (email.to - i.item_owner)
    }

    all i: (Item - linkFiles[email]) | {
        i.shared_with = i.shared_with'
    }

    -- And update shared_with_me.
    all d: Drive | d.shared_with_me in d.shared_with_me'

    all d: (location_owner.(email.to) & Drive) | {
        d.shared_with_me' = d.shared_with_me + (linkFiles[email] - d.location_items)
    }

    all d: (Drive - (location_owner.(email.to) & Drive)) | { d.shared_with_me' = d.shared_with_me }

   -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change,
    -- except the to drives' shared_with_me
    -- and the email map.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.location_items = l.location_items'
        l.location_items in l.location_items'

        l.power_state = l.power_state'
        l.power_state in l.power_state'
    }

    -- No items or their properties change,
    -- except the shared item(s)' shared_with.
    Item = Item'
    Item in Item'

    File = File'
    File in File'

    Folder = Folder'
    Folder in Folder'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with in i.shared_with'

        -- No file properties change.
        i.same_content = i.same_content'
        i.same_content in i.same_content'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No emails or their properties change.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }
}

// TODO: Test everything below.

pred sendReply[actor: Person, email: Email, reply_to: Email] {
    -- Guard(s):
    -- The actor cannot be server.
    actor != Server

    -- TODO: Power?

    -- The email must still be in the actor's drafts.
    email in inbox_owner.actor.drafts

    -- The reply_to must be in the actor's received.
    reply_to in inbox_owner.actor.received

    -- The email's to must have some overlap with reply_to's from.
    all r: email.to | r in reply_to.from

    -- The email's must have some sender, recipients, and content.
    some email.to
    some email.from
    some email.email_content

    -- Action(s):
    -- Email moves to sender's sent & recipients' received.
    inbox_owner.actor.sent in inbox_owner.actor.sent'
    inbox_owner.actor.sent' = inbox_owner.actor.sent + email

    all r: email.to | inbox_owner.r.received in inbox_owner.r.received'
    all r: email.to | inbox_owner.r.received' = inbox_owner.r.received + email

    -- Creates thread links in sender and recipients' mailbox.
    inbox_owner.actor.threads in inbox_owner.actor.threads'
    inbox_owner.actor.threads' = inbox_owner.actor.threads + email->reply_to

    all r: email.to | inbox_owner.r.threads in inbox_owner.r.threads'
    all r: email.to | inbox_owner.r.threads' = inbox_owner.r.threads + email->reply_to

    -- Email is no longer in the actor's drafts.
   (inbox_owner.actor).drafts' in (inbox_owner.actor).drafts
   (inbox_owner.actor).drafts' = (inbox_owner.actor).drafts - email

    -- No inboxes change.
    nochange_sig_Inbox

    -- No inbox ownerships changes.
    all i: Inbox | {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'
    }

    -- No threads change for anyone other than sender and recipients.
    all r: email.to | all i: ((Inbox - inbox_owner.r) - (inbox_owner.actor)) | {
        i.threads = i.threads'
        i.threads in i.threads'
    }

    -- No inbox sent or drafts are changed except for the actor's.
    all i: Inbox - (inbox_owner.actor) | {
        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'
    }

    -- No inbox receiveds change except for the email recipients.
    all r: email.to | all i: Inbox - inbox_owner.r | {
        i.received = i.received'
        i.received in i.received'
    }

    -- If email content is a link, share the item(s) it points to with recipients.
    all i: (linkFiles[email]) | {
        i.shared_with' = i.shared_with + (email.to - i.item_owner)
    }

    all i: (Item - linkFiles[email]) | {
        i.shared_with = i.shared_with'
    }

    -- And update shared_with_me.
    all d: Drive | d.shared_with_me in d.shared_with_me'

    all d: (location_owner.(email.to) & Drive) | {
        d.shared_with_me' = d.shared_with_me + (linkFiles[email] - d.location_items)
    }

    all d: (Drive - (location_owner.(email.to) & Drive)) | { d.shared_with_me' = d.shared_with_me }

   -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change,
    -- except the to drives' shared_with_me
    -- and the email map.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.location_items = l.location_items'
        l.location_items in l.location_items'

        l.power_state = l.power_state'
        l.power_state in l.power_state'
    }

    -- No items or their properties change,
    -- except the shared item(s)' shared_with.
    Item = Item'
    Item in Item'

    File = File'
    File in File'

    Folder = Folder'
    Folder in Folder'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with in i.shared_with'

        -- No file properties change.
        i.same_content = i.same_content'
        i.same_content in i.same_content'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No emails or their properties change.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }
}

pred editFile[actor: Person, file: File] {
    -- Guard(s):
    -- The item must be owned by or shared with the actor.
    (file.location in location_owner.actor) or (actor in file.shared_with)

    -- The actor cannot be server.
    actor != Server

    -- The file's location must be powered on.
    file.location.power_state = On

    -- Action(s):
    -- The file loses all its same_contents.
    no file.same_content'

    all i: Item - file | i.same_content' = i.same_content - file

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.location_items = l.location_items'
        l.location_items in l.location_items'

        l.power_state = l.power_state'
        l.power_state in l.power_state'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    -- No items or their properties change.
    Item = Item'
    Item in Item'

    File = File'
    File in File'

    Folder = Folder'
    Folder in Folder'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No emails or their properties change.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

pred downloadFileAttachment[actor: Person, email: Email] {
    -- Guard(s):
    -- The email must be in the actor's draft, sent, or received.
    email in inbox_owner.actor.drafts or
    email in inbox_owner.actor.received or
    email in inbox_owner.actor.sent

    -- The email must have a file attachment.
    email.email_content in Attachment
    email.email_content.attached in File

    -- The actor cannot be server.
    actor != Server

    -- The actor's computer must be powered on.
    (location_owner.actor & Computer).power_state = On

    -- The email server must be powered on.
    EmailServer.power_state = On

    -- Action(s):
    -- Create a new file on the actor's computer.
    some f: File' - File {
        -- Only one new item is created.
        File' = File + f

        -- Set the new file's location to the actor's computer.
        f.location' = (location_owner.actor & Computer)

        -- The computer gains no new items.
        (location_owner.actor & Computer).location_items in (location_owner.actor & Computer).location_items'
        (location_owner.actor & Computer).location_items' = (location_owner.actor & Computer).location_items + f

        -- Set the new file's creator and owner.
        f.item_owner' = actor
        f.item_creator' = email.email_content.attached.item_creator

        -- Ensure the new file isn't shared with anyone.
        no f.shared_with'

        -- Set all new same_content relations.
        f.same_content' = email.email_content.attached + email.email_content.attached.same_content

        email.email_content.attached.same_content' = email.email_content.attached.same_content + f
        email.email_content.attached.same_content in email.email_content.attached.same_content'

        all i: email.email_content.attached.same_content | {
            i.same_content' = i.same_content + f
            i.same_content in i.same_content'
        }
    }

    -- No non-related items' same_content changes.
    all i: (Item - (email.email_content.attached)) - email.email_content.attached.same_content | {
        i.same_content = i.same_content'
        i.same_content in i.same_content'    
    }

    -- No location items other than the actor's computer's change.
    all l: Location - (location_owner.actor & Computer) | {
        l.location_items = l.location_items'
        l.location_items in l.location_items'
    }

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.power_state = l.power_state'
        l.power_state in l.power_state'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    -- No existing items or their properties change.
    Item in Item'
    File in File'

    Folder = Folder'
    Folder in Folder'
    
    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No emails or their properties change.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

pred downloadDriveFile[actor: Person, file: File] {
    -- Guard(s):
    -- The file must be in the actor's Drive or shared_with_me.
    file in (location_owner.actor & Drive).location_items or
    file in (location_owner.actor & Drive).shared_with_me

    -- The actor cannot be server.
    actor != Server

    -- The file's location must be powered on.
    file.location.power_state = On

    -- The actor's computer must be powered on.
    (location_owner.actor & Computer).power_state = On

    -- Action(s):
    -- Create a new file on the actor's computer.
    some f: File' - File {
        -- Only one new item is created.
        File' = File + f

        -- Set the new file's location to the actor's computer.
        f.location' = (location_owner.actor & Computer)

        -- The computer gains no new items.
        (location_owner.actor & Computer).location_items in (location_owner.actor & Computer).location_items'
        (location_owner.actor & Computer).location_items' = (location_owner.actor & Computer).location_items + f

        -- Set the new file's creator and owner.
        f.item_owner' = actor
        f.item_creator' = file.item_creator

        -- Ensure the new file isn't shared with anyone.
        no f.shared_with'

        -- Set all new same_content relations.
        f.same_content' = file + file.same_content

        file.same_content' = file.same_content + f
        file.same_content in file.same_content'

        all i: file.same_content | {
            i.same_content' = i.same_content + f
            i.same_content in i.same_content'
        }
    }

    -- No non-related items' same_content changes.
    all i: (Item - (file)) - file.same_content | {
        i.same_content = i.same_content'
        i.same_content in i.same_content'    
    }

    -- No location items other than the actor's computer's change.
    all l: Location - (location_owner.actor & Computer) | {
        l.location_items = l.location_items'
        l.location_items in l.location_items'
    }

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.power_state = l.power_state'
        l.power_state in l.power_state'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    -- No existing items or their properties change.
    Item in Item'
    
    File in File'

    Folder = Folder'
    Folder in Folder'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No emails or their properties change.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

pred uploadFileToDrive[actor: Person, file: File] {
    -- Guard(s):
    -- The file must be on the actor's computer.
    file in (location_owner.actor & Computer).location_items

    -- The actor cannot be server.
    actor != Server

    -- The file's location must be powered on.
    file.location.power_state = On

    -- The actor's drive must be powered on.
    (location_owner.actor & Drive).power_state = On

    -- Action(s):
    -- Create a new file on the actor's drive.
    some f: File' - File {
        -- Only one new item is created.
        File' = File + f

        -- Set the new file's location to the actor's drove.
        f.location' = (location_owner.actor & Drive)

        -- The drive gains no new items.
        (location_owner.actor & Drive).location_items in (location_owner.actor & Drive).location_items'
        (location_owner.actor & Drive).location_items' = (location_owner.actor & Drive).location_items + f

        -- Set the new file's creator and owner.
        f.item_owner' = actor
        f.item_creator' = file.item_creator

        -- Ensure the new file isn't shared with anyone.
        no f.shared_with'

        -- Set all new same_content relations.
        f.same_content' = file + file.same_content

        file.same_content' = file.same_content + f
        file.same_content in file.same_content'

        all i: file.same_content | {
            i.same_content' = i.same_content + f
            i.same_content in i.same_content'
        }
    }

    -- No non-related items' same_content changes.
    all i: (Item - (file)) - file.same_content | {
        i.same_content = i.same_content'
        i.same_content in i.same_content'    
    }

    -- No location items other than the actor's drive's change.
    all l: Location - (location_owner.actor & Drive) | {
        l.location_items = l.location_items'
        l.location_items in l.location_items'
    }

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.power_state = l.power_state'
        l.power_state in l.power_state'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    -- No existing items or their properties change.
    Item in Item'

    File in File'

    Folder = Folder'
    Folder in Folder'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No emails or their properties change.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

pred duplicateFile[actor: Person, file: File] {
    -- Guard(s):
    -- The file must be owned by or shared with the actor.
    file in (location_owner.actor).location_items or
    file in (location_owner.actor & Drive).shared_with_me

    -- The actor cannot be server.
    actor != Server

    -- The file's location must be powered on.
    file.location.power_state = On

    -- Action(s):
    -- Create a new file on the actor's drive.
    some f: File' - File {
        -- Only one new item is created.
        File' = File + f

        -- Set the new file's location to the same as the file being duplicated.
        f.location' = file.location

        -- The drive gains no new items.
        file.location.location_items in file.location.location_items'
        file.location.location_items' = file.location.location_items + f

        -- Set the new file's creator and owner.
        f.item_owner' = actor
        f.item_creator' = actor

        -- Ensure the new file isn't shared with anyone.
        no f.shared_with'

        -- Set all new same_content relations.
        f.same_content' = file + file.same_content

        file.same_content' = file.same_content + f
        file.same_content in file.same_content'

        all i: file.same_content | {
            i.same_content' = i.same_content + f
            i.same_content in i.same_content'
        }
    }

    -- No non-related items' same_content changes.
    all i: (Item - (file)) - file.same_content | {
        i.same_content = i.same_content'
        i.same_content in i.same_content'    
    }

    -- No location items other than the actor's drive's change.
    all l: Location - file.location | {
        l.location_items = l.location_items'
        l.location_items in l.location_items'
    }

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.power_state = l.power_state'
        l.power_state in l.power_state'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    -- No existing items or their properties change.
    Item in Item'
    File in File'

    Folder = Folder'
    Folder in Folder'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No emails or their properties change.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

pred turnLocationOff[actor: Person, loc: Location] {
    -- Guard(s):
    -- The actor should own the location.
    loc.location_owner = actor

    -- The location should be on.
    loc.power_state = On

    -- Action(s):
    -- Turn the location off.
    loc.power_state' = Off

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change,
    -- except for the specified location's power_state state.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.location_items = l.location_items'
        l.location_items in l.location_items'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    all l: (Location - loc) | {
        l.power_state = l.power_state'
        l.power_state in l.power_state'
    }

    -- No items or their properties change.
    Item = Item'
    Item in Item'

    File = File'
    File in File'

    Folder = Folder'
    Folder in Folder'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No file properties change.
        i.same_content = i.same_content'
        i.same_content in i.same_content'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No emails or their properties change.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}

pred turnLocationOn[actor: Person, loc: Location] {
    -- Guard(s):
    -- The actor should own the location.
    loc.location_owner = actor

    -- The location should be off.
    loc.power_state = Off

    -- Action(s):
    -- Turn the location off.
    loc.power_state' = On

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change,
    -- except for the specified location's power_state state.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        l.location_items = l.location_items'
        l.location_items in l.location_items'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    all l: (Location - loc) | {
        l.power_state = l.power_state'
        l.power_state in l.power_state'
    }

    -- No items or their properties change.
    Item = Item'
    Item in Item'

    File = File'
    File in File'

    Folder = Folder'
    Folder in Folder'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No file properties change.
        i.same_content = i.same_content'
        i.same_content in i.same_content'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    Text = Text'
    Text in Text'

    Attachment = Attachment'
    Attachment in Attachment'

    Link = Link'
    Link in Link'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No emails or their properties change.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}


// TODO: Implement everything below.

pred downloadFolderAttachment[actor: Person, email: Email] {
    -- Guard(s):
    -- The email must be in the actor's draft, sent, or received.
    email in inbox_owner.actor.drafts or
    email in inbox_owner.actor.received or
    email in inbox_owner.actor.sent

    -- The email must have a folder attachment.
    email.email_content in Attachment
    email.email_content.attached in Folder

    -- The actor cannot be server.
    actor != Server

    -- Action(s):
    some folder: Folder' - Folder | {
        -- Only this new folder is created.
        Folder' = Folder + folder
        folder.location' = (location_owner.actor & Computer)
        folder.item_owner' = actor
        folder.item_creator' = email.email_content.attached.item_creator
        no folder.shared_with'

        let cloned_files = { cloned: File' | cloned not in File and cloned in File' - File } | {
            #{cloned_files} = #{email.email_content.attached.folder_items}
            folder.folder_items' = cloned_files

            -- Only these new files are created.
            File' = File + cloned_files

            cloned_files.location' = (location_owner.actor & Computer)
            cloned_files.item_owner' = actor
            cloned_files.item_creator' = email.email_content.attached.item_creator
            no cloned_files.shared_with'

            // -- The computer gains no other new items.
            // (location_owner.actor & Computer).location_items in (location_owner.actor & Computer).location_items'
            // (location_owner.actor & Computer).location_items' = (location_owner.actor & Computer).location_items + folder + cloned_files

            // all orig: email.email_content.attached.folder_items | one clone: cloned_files | {
            //     clone.same_content' = (orig + orig.same_content)  -- Mapping same_content individually.
            //     orig.same_content' = orig.same_content + clone
                
            //     all i: orig.same_content | {
            //         i.same_content' = i.^same_content + clone
            //     }
            // }
        }
    }

    -- No non-related items' same_content changes.
    // all i: (Item - (email.email_content.attached)) - email.email_content.attached.^same_content | {
    //     i.same_content = i.same_content'
    //     i.same_content in i.same_content'    
    // }

    // -- No location items other than the actor's computer's change.
    // all l: Location - (location_owner.actor & Computer) | {
    //     l.location_items = l.location_items'
    //     l.location_items in l.location_items'
    // }

    -- No persons change.
    nochange_sig_Person

    -- No locations or their properties change.
    nochange_sig_Location

    all l: Location | {
        l.location_owner = l.location_owner'
        l.location_owner in l.location_owner'

        -- No drive properties change.
        l.shared_with_me = l.shared_with_me'
        l.shared_with_me in l.shared_with_me'
    }

    -- No existing items or their properties change.
    Item in Item'

    all i: Item | {
        i.item_creator = i.item_creator'
        i.item_creator in i.item_creator'

        i.item_owner = i.item_owner'
        i.item_owner in i.item_owner'

        i.location = i.location'
        i.location in i.location'

        i.shared_with = i.shared_with'
        i.shared_with in i.shared_with'

        -- No folder properties change.
        i.folder_items = i.folder_items'
        i.folder_items in i.folder_items'
    }

    -- No email contents or their properties change.
    EmailContent = EmailContent'
    EmailContent in EmailContent'

    all ec: EmailContent | {
        -- No attachment properties change.
        ec.attached = ec.attached'
        ec.attached in ec.attached'

        -- No link properties change.
        ec.points_to = ec.points_to'
        ec.points_to in ec.points_to'
    }

    -- No emails or their properties change.
    Email = Email'
    Email in Email'

    all e: Email | {
        e.from = e.from'
        e.from in e.from'

        e.to = e.to'
        e.to in e.to'

        e.email_content = e.email_content'
        e.email_content in e.email_content'
    }

    -- No inboxes or their properties change.
    nochange_sig_Inbox

    all i: Inbox {
        i.inbox_owner = i.inbox_owner'
        i.inbox_owner in i.inbox_owner'

        i.received = i.received'
        i.received in i.received'

        i.sent = i.sent'
        i.sent in i.sent'

        i.drafts = i.drafts'
        i.drafts in i.drafts'

        i.threads = i.threads'
        i.threads in i.threads'
    }
}


pred downloadDriveFolder[actor: Person, item: Item] {

}

pred uploadFolderToDrive[actor: Person, item: Item] {

} 

pred unshareItem[actor: Person, item: Item] {

}

pred duplicateDriveFolder {

}

// pred deleteFile[actor: Person, file: File] {
//     -- Guard(s):
//     -- The actor must own the file.
//     file.item_owner = actor

//     -- The actor cannot be server.
//     actor != Server

//     -- Action(s):
//     -- Remove the file.
//     File' = File - file

//     -- All other items remain the same.
//     File' in File

//     Item' = Item - file
//     Item' in Item

//     Folder' = Folder
//     Folder in Folder'

//     -- All

//     -- No remaining item properties change except folder items & same content.
//     all i: Item - file | {
//         i.item_creator = i.item_creator'
//         i.item_creator in i.item_creator'

//         i.item_owner = i.item_owner'
//         i.item_owner in i.item_owner'

//         i.location = i.location'
//         i.location in i.location'

//         i.shared_with = i.shared_with'
//         i.shared_with in i.shared_with'
//     }

//     all i: Item - file.same_content {
//         i.same_content = i.same_content'
//         i.same_content in i.same_content'
//     }

//     all i: file.same_content {
//         i.same_content' = i.same_content - file
//         i.same_content' in i.same_content
//     }

//     folder_items' = folder_items - (Folder->file)
//     folder_items' in folder_items

//     -- No existing locations change.
//     Location = Location'
//     Location in Location'

//     all l: Location | {
//         l.location_owner = l.location_owner'
//         l.location_owner in l.location_owner'
//     }

//     shared_with_me' = shared_with_me - (Drive->file)
//     shared_with_me' in shared_with_me

//     all l: (Location) | {
//         l.location_items = l.location_items'
//         l.location_items in l.location_items'
//     }

//     -- No persons change.
//     Person = Person'
//     Person in Person'

//     -- No email contents or their properties change.
//     EmailContent = EmailContent'
//     EmailContent in EmailContent'

//     all ec: EmailContent | {
//         -- No attachment properties change.
//         ec.attached = ec.attached'
//         ec.attached in ec.attached'

//         -- No link properties change.
//         ec.points_to = ec.points_to'
//         ec.points_to in ec.points_to'
//     }

//     -- No emails or their properties change.
//     Email = Email'
//     Email in Email'

//     all e: Email | {
//         e.from = e.from'
//         e.from in e.from'

//         e.to = e.to'
//         e.to in e.to'

//         e.email_content = e.email_content'
//         e.email_content in e.email_content'
//     }

//     -- No inboxes or their properties change.
//     Inbox = Inbox'
//     Inbox in Inbox'

//     all i: Inbox {
//         i.inbox_owner = i.inbox_owner'
//         i.inbox_owner in i.inbox_owner'

//         i.received = i.received'
//         i.received in i.received'

//         i.sent = i.sent'
//         i.sent in i.sent'

//         i.drafts = i.drafts'
//         i.drafts in i.drafts'

//         i.threads = i.threads'
//         i.threads in i.threads'
//     }
// }

pred deleteFolder {
    -- TODO: what if the item is a folder with items?
    -- TODO: restrict to not server?
}

pred deleteEmail {

}

pred deleteThread {

}

------------------------ Run Statements ------------------------

pred initState {

}

pred finalState {
    testFinal
}

pred testInit {
    no Item
    no Email
    no EmailContent
}

pred testMid1 {
    some f: File | f in JoeDrive.location_items

}

pred testMid2 {
    some disj f1, f2: File |  {
        f1 in JoeDrive.location_items
        f2 in JoeComputer.location_items
        f1 in f2.same_content
    }
}

pred testFinal {
    // some e: Email | {
    //     some e.to
    //     some e.from
    //     some e.email_content
    //     e.email_content in Attachment
    //     some f: Folder | {
    //         some f.folder_items
    //         e.email_content.attached = f
    //     }
    // }

    // some sent

    // some disj f1, f2: File, fold1, fold2: Folder | {
    //     f1 in fold1.folder_items
    //     f2 in fold2.folder_items
    //     f3 in fold3.folder_items

    //     f2 in f1.same_content
    //     f3 in f1.same_content

    //     f1.location = JoeComputer
    //     f2.location = BobbiComputer
    //     f3.location = EmailServer
        
    //     f2.item_creator = Joe
    //     f3.item_creator = Joe
    // }

    some disj f1, f2, f3: File | {
        f1.location = JoeComputer
        f2.location = BobbiComputer
        f3.location = EmailServer
        f2 in f1.same_content
        f3 in f1.same_content
        
        f2.item_creator = Joe
        f3.item_creator = Joe
    }

    some f4: File, fold: Folder | {
        f4 in fold.folder_items
        f4.location in Drive
    }

    some shared_with_me

    // some disj f1, f2, f3: File | {
    //     f1.location = JoeDrive
    //     f2.location = JoeDrive
    //     f3.location = JoeComputer
    //     f1 in f3.same_content
    //     f2 in f3.same_content
    // }
}

pred testTraces {
    testInit
    modelProperties and ownership
    always {
       doNothing or {
            some p: (Person - Server), l: Location | { createFile[p, l] }
        } or {
            some p: (Person - Server), l: Location | { createFolder[p, l] }
        } or {
            // TN: changed from m: Item. Either need to narrow the argument 
            //   or make the declaration more permissive.
            some p: Person, m: File, d: Folder | { moveItem[p, m, d] }
        } or {
            some p: Person | { createEmail[p] }
        } or {
            some p, r: Person, e: Email | { setRecipients[p, e, r] }
        } or {
            some p: Person, i: Item, e: Email | { addLink[p, i, e] }
        } or {
            some p: Person, e: Email | { sendEmail[p, e] }
        } or {
            some p: Person, a: File, e: Email | { attachFile[p, a, e] }
        } or {
            some p: Person, a: Folder, e: Email | { attachFolder[p, a, e] }
        } or {
            some p: Person, e: Email | { addText[p, e] } 
        } or {
            some p: Person, f: File | { editFile[p, f] }
        } or {
            some p: Person, e, r: Email | sendReply[p, e, r]
        } or {
            some p: Person, e: Email | downloadFileAttachment[p, e]
        }
    }
    // eventually {testMid1}
    // eventually {testMid2}
    eventually {always {testFinal}}
    // eventually {always {not modelProperties}}
}
run {
    testTraces
} for exactly 3 Person,
    exactly 5 Location, exactly 2 Drive, exactly 2 Computer, 
    exactly 1 EmailServer, exactly 2 Inbox,
    8 Item, 7 File, 1 Folder,
    2 EmailContent, 2 Email

    // always {
    //     doNothing or {
    //         some p: (Person - Server), l: Location | { createFile[p, l] }
    //     } or {
    //         some p: (Person - Server), l: Location | { createFolder[p, l] }
    //     } or {
    //         some p: Person, m: Item, d: Folder | { moveItem[p, m, d] }
    //     } or {
    //         some p: Person | { createEmail[p] }
    //     } or {
    //         some p, r: Person, e: Email | { setRecipients[p, e, r] }
    //     } or {
    //         some p: Person, e: Email | { sendEmail[p, e] }
    //     } or {
    //         some p: Person, a: File, e: Email | { attachFile[p, a, e] }
    //     } or {
    //         some p: Person, a: Folder, e: Email | { attachFolder[p, a, e] }
    //     } or {
    //         some p: Person, e: Email | { addText[p, e] } 
    //     } or {
    //         some p: Person, f: File | { editFile[p, f] }
    //     } or {
    //         some p: Person, e, r: Email | sendReply[p, e, r]
    //     } or {
    //         some p: Person, e: Email | downloadFileAttachment[p, e]
    //     }
    // }

        //     doNothing or {
        //     some p: (Person - Server), l: Location | { createFile[p, l] }
        // } or {
        //     some p: (Person - Server), l: Location | { createFolder[p, l] }
        // } or {
        //     some p: Person, m: Item, d: Folder | { moveItem[p, m, d] }
        // } or {
        //     some p: Person, f: File | { editFile[p, f] }
        // } or {
        //     some p: Person, f: File | { downloadDriveFile[p, f] }
        // } or {
        //     some p: Person, f: File | { uploadFileToDrive[p, f] }
        // }


    // always {
    //     doNothing or {
    //         some p: (Person - Server), l: Location | { createFile[p, l] }
    //     } or {
    //         some p: (Person - Server), l: Location | { createFolder[p, l] }
    //     } or {
    //         some p: Person, m: Item, d: Folder | { moveItem[p, m, d] }
    //     } or {
    //         some p: Person | { createEmail[p] }
    //     } or {
    //         some p, r: Person, e: Email | { setRecipients[p, e, r] }
    //     } or {
    //         some p: Person, e: Email | { sendEmail[p, e] }
    //     } or {
    //         some p: Person, a: File, e: Email | { attachFile[p, a, e] }
    //     } or {
    //         some p: Person, f: File | { editFile[p, f] }
    //     } or {
    //         some p: Person, e, r: Email | sendReply[p, e, r]
    //     } or {
    //         some p: Person, e: Email | downloadFileAttachment[p, e]
    //     }
    // }

    // TODO: Carry over old.frg todo's.
    // TODO: Fix Items changing into folders.
    // TODO: Think about all X THAT EXISTED BEFORE

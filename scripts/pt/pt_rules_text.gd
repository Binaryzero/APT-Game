extends RefCounted
## BBCode text for the in-game rules reference.

const RULES := """[font_size=22][color=#27d3f5][b]GOAL[/b][/color][/font_size]
Be the first player to control [b]6 servers[/b] in your NETWORK (the table can be set to 5 or 7). If the DECK runs out first, the player with the most servers wins. Ties: fewest Malware in your network, then most Software, then a best-of-three Rock-Paper-Scissors duel.

[font_size=22][color=#27d3f5][b]YOUR TURN[/b][/color][/font_size]
[color=#3dff8e][b]1  BEGIN[/b][/color]  Every [i]"at the beginning of your turn"[/i] effect in your network happens. Mandatory effects always happen; "you MAY" effects are optional.
[color=#3dff8e][b]2  DRAW[/b][/color]  Draw one card from the DECK (some cards change this number).
[color=#3dff8e][b]3  ACT[/b][/color]  Play [b]one[/b] card from your hand (Server, Software, Malware or Exploit), [b]or[/b] draw one more card instead. Some cards grant extra plays.
[color=#3dff8e][b]4  DISCARD[/b][/color]  Discard down to your hand limit. The limit is [b]7[/b], raised or lowered by cards in your network.

Your hand is private. Only a Traffic Sniffer exposes it.

[font_size=22][color=#27d3f5][b]YOUR NETWORK[/b][/color][/font_size]
Servers sit in a row. Each Server can carry [b]one Software[/b] and [b]one Malware[/b], shown stacked above it.
  [color=#27d3f5]Production Servers[/color] have ENTER, LEAVE or BEGINNING effects. [color=#6f93ff]Staging Servers[/color] have none.
  [color=#3dff8e]Software[/color] helps its owner. It can only be installed on a Server in [i]your own[/i] network that has no Malware.
  [color=#ff5a3c]Malware[/color] hurts whoever owns the network it is in. It can be installed on [i]any[/i] Server, even yours. Malware sits on top of Software and switches that Software [b]off[/b] while it stays there.
  Effects of Software and Malware apply to the whole network. Cards in your hand have no effect.
  If a Server leaves your network for any reason, the Software and Malware on it are discarded.
  When a Server is stolen, its LEAVE effect happens for the old owner first, then its ENTER effect happens for the new owner.

[font_size=22][color=#ffb21f][b]EXPLOITS[/b][/color][/font_size]
Single-use cards that are discarded after they resolve. They can [b]DELETE[/b], [b]STEAL[/b], [b]UNINSTALL[/b] or [b]DISCARD[/b] cards, or give you card advantage. You may target yourself when it makes sense, for example to purge your own Malware.

[font_size=22][color=#c77dff][b]0DAY CARDS[/b][/color][/font_size]
A 0DAY can be played [b]at any time[/b], even while another player's card is being played. You can chain them, and every 0DAY can itself be answered by another 0DAY. The newest card resolves first.
  [b]Small DDoS[/b] cancels any card that is being played.
  [b]Process Kill[/b] stops a card from entering a network and draws you a card.
  [b]Remote Root[/b] blocks (or reflects) an Exploit that would delete, steal or move cards in [i]your[/i] network.
  [b]Backdoor Cache[/b] draws two cards, on your own turn, without using your play.
A 0DAY changes what happens when a card is [i]played[/i]. It cannot undo effects of cards that are already in a network.

[font_size=22][color=#27d3f5][b]KEY WORDS[/b][/color][/font_size]
[b]DELETE[/b] a card from any network to the discard pile.   [b]UNINSTALL[/b] a card from your own network to the discard pile.
[b]STEAL[/b] a card from another network into yours.   [b]DISCARD[/b] a card from your hand.   [b]Each player[/b] includes you; [b]another player[/b] does not.
If an effect has two steps and the first cannot happen, the second does not happen either.
A card hidden under Malware cannot be reached by effects that move cards out of a network.

[font_size=22][color=#27d3f5][b]CONTROLS[/b][/color][/font_size]
Click a card in your hand to select it, then press [b]PLAY[/b]. Pick targets by clicking highlighted cards in a network. Hover any card to read it in the inspector on the right. The event log shows what happened, in order.
"""

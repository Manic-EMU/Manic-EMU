//
//  ChatMessageRequest.swift
//  DeepSwiftSeek
//
//  Created by Tornike Gomareli on 29.01.25.
//


//
//  ChatMessage.swift
//  DeepSwiftSeek
//
//  Created by Tornike Gomareli on 29.01.25.
//

public struct ChatMessageRequest: Codable, Sendable {
  public let role: MessegingRole
  public let content: String
  
  public init(role: MessegingRole, content: String) {
    self.role = role
    self.content = content
  }
}

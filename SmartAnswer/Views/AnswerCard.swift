import SwiftUI

struct AnswerCard: View {
    let question: Question
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Source badge
            HStack {
                Image(systemName: question.source == "local" ? "books.vertical.fill" : "brain")
                    .font(.caption2)
                Text(question.source == "local" ? "本地题库" : "DeepSeek AI")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(question.source == "local" ? Color.green : Color.blue)
            .cornerRadius(6)
            
            // Question
            Text(question.question)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // Answer
            Text(question.answer)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}
